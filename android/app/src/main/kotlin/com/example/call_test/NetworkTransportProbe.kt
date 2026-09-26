package com.example.call_test

import android.os.Handler
import android.os.Looper
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

object NetworkTransportProbe {
    private const val TAG = "NetworkTransportProbe"
    private val isRunning = AtomicBoolean(false)
    private var workerThread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    data class TransportStats(
        val packetsSent: Long,
        val packetsReceived: Long,
        val packetLossPercent: Double,
        val avgLatencyMs: Double,
        val jitterMs: Double,
        val bitrateKbps: Double,
        val status: String
    )

    fun startTransportBenchmark(
        targetHost: String = "127.0.0.1",
        targetPort: Int = 19876,
        durationSeconds: Int = 10,
        packetIntervalMs: Long = 20, // Standard 20ms VoIP audio frame
        onProgress: (TransportStats) -> Unit,
        onComplete: (TransportStats) -> Unit
    ) {
        stopTransportBenchmark()
        isRunning.set(true)

        workerThread = Thread({
            var socket: DatagramSocket? = null
            var echoSocket: DatagramSocket? = null

            var sentCount = 0L
            var recvCount = 0L
            var totalLatencyMs = 0.0
            var lastLatencyMs = 0.0
            var jitterAccum = 0.0

            val framePayloadSize = 160 * 2 // 160 samples (20ms at 8kHz or Opus frame) + 16 byte header

            try {
                // If localhost, create an echo receiver socket for loopback testing
                val isLocalhost = targetHost == "127.0.0.1" || targetHost == "localhost"
                if (isLocalhost) {
                    echoSocket = DatagramSocket(targetPort)
                    Thread({
                        val echoBuf = ByteArray(1024)
                        val echoPacket = DatagramPacket(echoBuf, echoBuf.size)
                        while (isRunning.get() && echoSocket?.isClosed == false) {
                            try {
                                echoSocket.receive(echoPacket)
                                echoSocket.send(DatagramPacket(echoPacket.data, echoPacket.length, echoPacket.address, echoPacket.port))
                            } catch (e: Exception) {
                                break
                            }
                        }
                    }, "TransportEchoWorker").start()
                }

                socket = DatagramSocket()
                socket.soTimeout = 500
                val targetAddress = InetAddress.getByName(targetHost)

                val startTime = System.currentTimeMillis()
                val endTime = startTime + (durationSeconds * 1000L)
                val buffer = ByteArray(framePayloadSize)

                CallStreamingServiceControl.log(TAG, "Starting transport benchmark to $targetHost:$targetPort (Interval: ${packetIntervalMs}ms)")

                while (isRunning.get() && System.currentTimeMillis() < endTime) {
                    sentCount++
                    val sendTimestamp = System.currentTimeMillis()

                    // Build packet: [seq (long: 8)][timestamp (long: 8)][dummy payload]
                    val byteBuffer = ByteBuffer.wrap(buffer)
                    byteBuffer.putLong(sentCount)
                    byteBuffer.putLong(sendTimestamp)

                    val sendPacket = DatagramPacket(buffer, buffer.size, targetAddress, targetPort)
                    socket.send(sendPacket)

                    // Receive echo/response
                    try {
                        val recvBuf = ByteArray(framePayloadSize)
                        val recvPacket = DatagramPacket(recvBuf, recvBuf.size)
                        socket.receive(recvPacket)

                        val recvBuffer = ByteBuffer.wrap(recvBuf)
                        val recvSeq = recvBuffer.long
                        val recvTs = recvBuffer.long

                        if (recvSeq == sentCount) {
                            recvCount++
                            val rtt = (System.currentTimeMillis() - recvTs).toDouble()
                            totalLatencyMs += rtt

                            if (recvCount > 1) {
                                val diff = abs(rtt - lastLatencyMs)
                                jitterAccum += (diff - jitterAccum) / 16.0
                            }
                            lastLatencyMs = rtt
                        }
                    } catch (e: Exception) {
                        // Packet dropped or timeout
                    }

                    if (sentCount % 25L == 0L) {
                        val elapsedSec = (System.currentTimeMillis() - startTime) / 1000.0
                        val loss = if (sentCount > 0) ((sentCount - recvCount).toDouble() / sentCount) * 100.0 else 0.0
                        val avgLat = if (recvCount > 0) totalLatencyMs / recvCount else 0.0
                        val bitrate = if (elapsedSec > 0) ((sentCount * framePayloadSize * 8) / 1000.0) / elapsedSec else 0.0

                        val stats = TransportStats(
                            packetsSent = sentCount,
                            packetsReceived = recvCount,
                            packetLossPercent = loss,
                            avgLatencyMs = avgLat,
                            jitterMs = jitterAccum,
                            bitrateKbps = bitrate,
                            status = "RUNNING"
                        )
                        mainHandler.post { onProgress(stats) }
                    }

                    Thread.sleep(packetIntervalMs)
                }

                val finalElapsedSec = (System.currentTimeMillis() - startTime) / 1000.0
                val finalLoss = if (sentCount > 0) ((sentCount - recvCount).toDouble() / sentCount) * 100.0 else 0.0
                val finalAvgLat = if (recvCount > 0) totalLatencyMs / recvCount else 0.0
                val finalBitrate = if (finalElapsedSec > 0) ((sentCount * framePayloadSize * 8) / 1000.0) / finalElapsedSec else 0.0

                val finalStats = TransportStats(
                    packetsSent = sentCount,
                    packetsReceived = recvCount,
                    packetLossPercent = finalLoss,
                    avgLatencyMs = finalAvgLat,
                    jitterMs = jitterAccum,
                    bitrateKbps = finalBitrate,
                    status = "COMPLETED"
                )

                CallStreamingServiceControl.log(TAG, "Transport benchmark completed: Sent=$sentCount, Recv=$recvCount, Loss=${String.format("%.1f", finalLoss)}%, AvgRTT=${String.format("%.1f", finalAvgLat)}ms, Jitter=${String.format("%.2f", jitterAccum)}ms")
                mainHandler.post { onComplete(finalStats) }

            } catch (e: Exception) {
                CallStreamingServiceControl.log(TAG, "Transport benchmark error: ${e.message}", "ERROR")
            } finally {
                socket?.close()
                echoSocket?.close()
                isRunning.set(false)
            }
        }, "NetworkTransportWorker")

        workerThread?.start()
    }

    fun stopTransportBenchmark() {
        isRunning.set(false)
        workerThread?.interrupt()
        workerThread = null
    }
}
