package com.cka.lecteur_musique_cka

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Activité principale. Elle hérite d'AudioServiceActivity pour la lecture en
 * arrière-plan, et expose au code Flutter (canal « cka/musique ») :
 * l'autorisation d'accès à la musique, la liste des chansons du téléphone
 * et les pochettes d'albums.
 */
class MainActivity : AudioServiceActivity() {
    private var resultatPermission: MethodChannel.Result? = null
    private var resultatMicro: MethodChannel.Result? = null
    private var resultatSuppression: MethodChannel.Result? = null
    private var aSupprimer: List<Long> = emptyList()
    private val executeur = Executors.newFixedThreadPool(3)

    private val permission: String
        get() = if (Build.VERSION.SDK_INT >= 33) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_ANALYSEUR)
            .setStreamHandler(Analyseur())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "aPermission" -> resultat.success(aPermission())
                    "demanderPermission" -> demanderPermission(resultat)
                    "chansons" -> executeur.execute {
                        val chansons = try {
                            lireChansons()
                        } catch (e: Exception) {
                            emptyList()
                        }
                        runOnUiThread { resultat.success(chansons) }
                    }
                    "partager" -> {
                        val ids = appel.argument<List<Number>>("ids")!!.map { it.toLong() }
                        resultat.success(partager(ids))
                    }
                    "supprimer" -> {
                        val ids = appel.argument<List<Number>>("ids")!!.map { it.toLong() }
                        supprimer(ids, resultat)
                    }
                    "aMicro" -> resultat.success(aMicro())
                    "demanderMicro" -> demanderMicro(resultat)
                    "details" -> {
                        val id = appel.argument<Number>("id")!!.toLong()
                        executeur.execute {
                            val details = try {
                                details(id)
                            } catch (e: Exception) {
                                emptyMap()
                            }
                            runOnUiThread { resultat.success(details) }
                        }
                    }
                    "pochette" -> {
                        val albumId = appel.argument<Number>("albumId")!!.toLong()
                        val chansonId = appel.argument<Number>("chansonId")!!.toLong()
                        executeur.execute {
                            val chemin = pochette(albumId, chansonId)
                            runOnUiThread { resultat.success(chemin) }
                        }
                    }
                    else -> resultat.notImplemented()
                }
            }
    }

    private fun aPermission() =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun demanderPermission(resultat: MethodChannel.Result) {
        if (aPermission()) {
            resultat.success(true)
            return
        }
        resultatPermission = resultat
        val demandees = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(permission, Manifest.permission.POST_NOTIFICATIONS)
        } else {
            arrayOf(permission)
        }
        requestPermissions(demandees, CODE_PERMISSION)
    }

    private fun aMicro() =
        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun demanderMicro(resultat: MethodChannel.Result) {
        if (aMicro()) {
            resultat.success(true)
            return
        }
        resultatMicro = resultat
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), CODE_MICRO)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CODE_PERMISSION) {
            resultatPermission?.success(aPermission())
            resultatPermission = null
        }
        if (requestCode == CODE_MICRO) {
            resultatMicro?.success(aMicro())
            resultatMicro = null
        }
        if (requestCode == CODE_ECRITURE) {
            val resultat = resultatSuppression ?: return
            resultatSuppression = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                supprimerDirectement(aSupprimer, resultat)
            } else {
                resultat.success(emptyList<Long>())
            }
        }
    }

    /**
     * Ouvre le menu de partage d'Android (WhatsApp, Bluetooth, Xender…)
     * avec les fichiers audio de ces chansons.
     */
    private fun partager(ids: List<Long>): Boolean {
        if (ids.isEmpty()) return false
        val uris = ArrayList(ids.map(::uriDe))
        val intention = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        }
        intention.type = "audio/*"
        // Autorise l'application choisie à lire ces fichiers.
        intention.clipData = ClipData.newRawUri(null, uris[0]).apply {
            uris.drop(1).forEach { addItem(ClipData.Item(it)) }
        }
        intention.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val titre = if (uris.size == 1) "Partager le titre" else "Partager ${uris.size} titres"
        return try {
            startActivity(Intent.createChooser(intention, titre))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun uriDe(id: Long): Uri =
        ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)

    /**
     * Efface des chansons du téléphone. Depuis Android 11, c'est Android qui
     * demande confirmation ; avant, il faut l'autorisation d'écrire.
     * Répond avec la liste des identifiants vraiment effacés.
     */
    private fun supprimer(ids: List<Long>, resultat: MethodChannel.Result) {
        if (ids.isEmpty()) {
            resultat.success(emptyList<Long>())
            return
        }
        if (resultatSuppression != null) {
            resultat.error("occupe", "Une suppression est déjà en cours", null)
            return
        }
        aSupprimer = ids
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                val demande = MediaStore.createDeleteRequest(contentResolver, ids.map(::uriDe))
                resultatSuppression = resultat
                startIntentSenderForResult(demande.intentSender, CODE_SUPPRESSION, null, 0, 0, 0)
            } catch (e: Exception) {
                resultatSuppression = null
                resultat.error("suppression", e.message, null)
            }
            return
        }
        val ecriture = Manifest.permission.WRITE_EXTERNAL_STORAGE
        if (checkSelfPermission(ecriture) != PackageManager.PERMISSION_GRANTED) {
            resultatSuppression = resultat
            requestPermissions(arrayOf(ecriture), CODE_ECRITURE)
            return
        }
        supprimerDirectement(ids, resultat)
    }

    private fun supprimerDirectement(ids: List<Long>, resultat: MethodChannel.Result) {
        executeur.execute {
            val effaces = ids.filter { id ->
                try {
                    contentResolver.delete(uriDe(id), null, null) > 0
                } catch (e: Exception) {
                    false
                }
            }
            runOnUiThread { resultat.success(effaces) }
        }
    }

    private fun existe(id: Long): Boolean = try {
        contentResolver.query(uriDe(id), arrayOf(MediaStore.Audio.Media._ID), null, null, null)
            ?.use { it.moveToFirst() } ?: false
    } catch (e: Exception) {
        false
    }

    @Deprecated("Utilisé pour la confirmation de suppression d'Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CODE_SUPPRESSION) return
        val resultat = resultatSuppression ?: return
        resultatSuppression = null
        if (resultCode != Activity.RESULT_OK) {
            resultat.success(emptyList<Long>())
            return
        }
        val ids = aSupprimer
        executeur.execute {
            val effaces = ids.filter { !existe(it) }
            runOnUiThread { resultat.success(effaces) }
        }
    }

    /** Toutes les musiques du téléphone (au moins 30 s, sans sonneries ni notes vocales). */
    private fun lireChansons(): List<Map<String, Any?>> {
        val colonnes = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.DISPLAY_NAME,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
            "${MediaStore.Audio.Media.DURATION} >= 30000"
        val chansons = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            colonnes,
            selection,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            val iId = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val iTitre = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val iArtiste = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val iAlbum = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val iAlbumId = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val iDuree = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val iAjout = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val iAnnee = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val iFichier = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            while (c.moveToNext()) {
                val id = c.getLong(iId)
                chansons.add(
                    mapOf(
                        "id" to id,
                        "titre" to c.getString(iTitre),
                        "artiste" to c.getString(iArtiste),
                        "album" to c.getString(iAlbum),
                        "albumId" to c.getLong(iAlbumId),
                        "duree" to c.getLong(iDuree),
                        "ajout" to c.getLong(iAjout),
                        // Année du titre (étiquette du fichier), 0 si inconnue.
                        "annee" to if (c.isNull(iAnnee)) 0 else c.getInt(iAnnee),
                        // Nom du fichier : l'année y est souvent écrite.
                        "fichier" to c.getString(iFichier),
                        "uri" to ContentUris.withAppendedId(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                            id,
                        ).toString(),
                    ),
                )
            }
        }
        return chansons
    }

    /** Informations détaillées d'une chanson : fichier, format, taille, débit… */
    private fun details(id: Long): Map<String, Any?> {
        val colonnes = mutableListOf(
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.COMPOSER,
        )
        if (Build.VERSION.SDK_INT >= 29) colonnes.add(MediaStore.Audio.Media.RELATIVE_PATH)
        if (Build.VERSION.SDK_INT >= 30) {
            colonnes.add(MediaStore.Audio.Media.BITRATE)
            colonnes.add(MediaStore.Audio.Media.GENRE)
        }
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
        contentResolver.query(uri, colonnes.toTypedArray(), null, null, null)?.use { c ->
            if (!c.moveToFirst()) return emptyMap()
            fun texte(nom: String) = c.getColumnIndex(nom).takeIf { it >= 0 }?.let { c.getString(it) }
            fun nombre(nom: String) = c.getColumnIndex(nom).takeIf { it >= 0 && !c.isNull(it) }?.let { c.getLong(it) }
            return mapOf(
                "fichier" to texte(MediaStore.Audio.Media.DISPLAY_NAME),
                "dossier" to texte("relative_path"),
                "taille" to nombre(MediaStore.Audio.Media.SIZE),
                "format" to texte(MediaStore.Audio.Media.MIME_TYPE),
                "annee" to nombre(MediaStore.Audio.Media.YEAR),
                "piste" to nombre(MediaStore.Audio.Media.TRACK),
                "compositeur" to texte(MediaStore.Audio.Media.COMPOSER),
                "debit" to nombre("bitrate"),
                "genre" to texte("genre"),
            )
        }
        return emptyMap()
    }

    /**
     * Chemin d'un fichier JPEG de la pochette (mis en cache), ou null s'il n'y en a pas.
     * Un fichier vide dans le cache veut dire « pas de pochette ».
     */
    private fun pochette(albumId: Long, chansonId: Long): String? {
        val fichier = File(cacheDir, "pochettes/$albumId.jpg")
        if (fichier.exists()) return if (fichier.length() > 0) fichier.path else null
        fichier.parentFile?.mkdirs()

        var image: Bitmap? = null
        if (Build.VERSION.SDK_INT >= 29) {
            val sources = listOf(
                ContentUris.withAppendedId(MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI, albumId),
                ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, chansonId),
            )
            for (uri in sources) {
                image = try {
                    contentResolver.loadThumbnail(uri, Size(512, 512), null)
                } catch (e: Exception) {
                    null
                }
                if (image != null) break
            }
        } else {
            image = try {
                contentResolver
                    .openInputStream(Uri.parse("content://media/external/audio/albumart/$albumId"))
                    ?.use { BitmapFactory.decodeStream(it) }
            } catch (e: Exception) {
                null
            }
        }

        val trouvee = image
        if (trouvee == null) {
            fichier.createNewFile()
            return null
        }
        FileOutputStream(fichier).use { trouvee.compress(Bitmap.CompressFormat.JPEG, 88, it) }
        return fichier.path
    }

    companion object {
        private const val CANAL = "cka/musique"
        private const val CANAL_ANALYSEUR = "cka/analyseur"
        private const val CODE_PERMISSION = 42
        private const val CODE_MICRO = 43
        private const val CODE_ECRITURE = 44
        private const val CODE_SUPPRESSION = 45
    }
}
