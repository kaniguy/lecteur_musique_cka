package com.cka.lecteur_musique_cka

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import kotlin.math.hypot
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow

/**
 * Mesure le son qui sort du lecteur (session audio donnée) et envoie à Flutter,
 * environ 20 fois par seconde, le niveau de [NOMBRE_BANDES] bandes de
 * fréquences, des graves aux aigus, chacun entre 0 et 1.
 *
 * Android exige l'autorisation « Micro » pour ce type de mesure, même si rien
 * n'est enregistré.
 */
class Analyseur : EventChannel.StreamHandler {
    private var sortie: EventChannel.EventSink? = null
    private var visualiseur: Visualizer? = null
    private val principal = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sortie = events
        val session = (arguments as? Number)?.toInt() ?: return
        demarrer(session)
    }

    override fun onCancel(arguments: Any?) {
        arreter()
        sortie = null
    }

    private fun demarrer(session: Int) {
        arreter()
        try {
            val v = Visualizer(session)
            v.captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024)
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(vis: Visualizer?, onde: ByteArray?, taux: Int) {}

                    override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, taux: Int) {
                        val niveaux = fft?.let { bandes(it) } ?: return
                        principal.post { sortie?.success(niveaux) }
                    }
                },
                Visualizer.getMaxCaptureRate(),
                false,
                true,
            )
            v.enabled = true
            visualiseur = v
        } catch (e: Exception) {
            principal.post { sortie?.error("analyseur", e.message, null) }
        }
    }

    private fun arreter() {
        visualiseur?.let {
            try {
                it.enabled = false
                it.release()
            } catch (_: Exception) {
            }
        }
        visualiseur = null
    }

    /** Regroupe la FFT en bandes réparties sur une échelle logarithmique. */
    private fun bandes(fft: ByteArray): List<Double> {
        val n = fft.size / 2
        val niveaux = ArrayList<Double>(NOMBRE_BANDES)
        for (b in 0 until NOMBRE_BANDES) {
            val debut = max(1, (n.toDouble().pow(b.toDouble() / NOMBRE_BANDES)).toInt())
            val fin = max(debut + 1, (n.toDouble().pow((b + 1).toDouble() / NOMBRE_BANDES)).toInt())
            var somme = 0.0
            var compte = 0
            for (k in debut until minOf(fin, n)) {
                val re = fft[2 * k].toDouble()
                val im = fft[2 * k + 1].toDouble()
                somme += hypot(re, im)
                compte++
            }
            val amplitude = if (compte == 0) 0.0 else somme / compte
            // En décibels, ramenés entre 0 (silence) et 1 (très fort).
            val db = 20 * log10(amplitude + 1)
            niveaux.add((db / 42.0).coerceIn(0.0, 1.0))
        }
        return niveaux
    }

    companion object {
        const val NOMBRE_BANDES = 28
    }
}
