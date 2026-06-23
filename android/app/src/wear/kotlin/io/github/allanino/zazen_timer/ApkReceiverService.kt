package io.github.allanino.zazen_timer

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.google.android.gms.wearable.ChannelClient
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import java.io.File

class ApkReceiverService : WearableListenerService() {
    override fun onChannelOpened(channel: ChannelClient.Channel) {
        if (channel.path == "/install_apk") {
            val apkFile = File(cacheDir, "update.apk")
            val channelClient = Wearable.getChannelClient(this)

            channelClient.receiveFile(channel, Uri.fromFile(apkFile), false)
                .addOnSuccessListener {
                    channelClient.registerChannelCallback(channel, object : ChannelClient.ChannelCallback() {
                        override fun onInputClosed(c: ChannelClient.Channel, closeReason: Int, appSpecificErrorCode: Int) {
                            if (closeReason == ChannelClient.ChannelCallback.CLOSE_REASON_NORMAL) {
                                installApk(apkFile)
                            }
                        }
                    })
                }
        }
    }

    private fun installApk(apkFile: File) {
        val uri = FileProvider.getUriForFile(this, "\$packageName.fileprovider", apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        startActivity(intent)
    }
}
