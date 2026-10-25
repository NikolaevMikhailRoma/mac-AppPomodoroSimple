package com.nikolaev.pomodoro.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.zxing.BinaryBitmap
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import com.nikolaev.pomodoro.core.PairLink
import java.util.concurrent.Executors

/**
 * The camera, for the QR on the Mac only. The permission is asked here, the
 * first time the scanner opens; without it the screen says why it needs it.
 */
@Composable
fun PairScreen(onLink: (PairLink) -> Unit, onBack: () -> Unit) {
    val context = LocalContext.current
    var allowed by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    // After a refusal Android may not show the dialog again: then the button opens the app's settings.
    var refused by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        allowed = it
        refused = !it
    }
    LaunchedEffect(Unit) { if (!allowed) ask.launch(Manifest.permission.CAMERA) }
    LifecycleResumeEffect(Unit) {
        // Back from the app's settings.
        allowed = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        onPauseOrDispose {}
    }

    val s = Design.settings
    val label = textStyle((s["labelSize"] * Design.phone["settingsScale"]).sp, s.color("labelColor"))
    Column(Modifier.fillMaxSize().background(s.color("background")).safeDrawingPadding()) {
        TitleBar("Pair with Mac", onBack)
        Column(Modifier.padding(horizontal = Design.phone["margin"].dp)) {
            Text(
                "On the Mac: Pomodoro → Settings → Devices → Pair a Phone. Then point the camera at the code.",
                style = label,
                modifier = Modifier.padding(vertical = 16.dp),
            )
            Box(
                Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(s["cornerRadius"].dp)).background(s.color("boxBackground")),
                contentAlignment = Alignment.Center,
            ) {
                if (allowed) {
                    Scanner(onLink)
                } else {
                    Text(
                        "Pomodoro needs the camera only to read this code.",
                        style = label.copy(color = s.color("sectionHeaderColor")),
                        modifier = Modifier.padding(24.dp),
                    )
                }
            }
            if (!allowed) {
                Text(
                    "Allow the camera",
                    style = label.copy(color = Design.phone.color("tint")),
                    modifier = Modifier.clickable {
                        if (refused) {
                            context.startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
                            )
                        } else {
                            ask.launch(Manifest.permission.CAMERA)
                        }
                    }.padding(vertical = 16.dp),
                )
            }
        }
    }
}

@Composable
private fun Scanner(onLink: (PairLink) -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val analyzer = remember { Executors.newSingleThreadExecutor() }
    var done by remember { mutableStateOf(false) }
    val provider = remember { ProcessCameraProvider.getInstance(context) }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            PreviewView(ctx).also { view ->
                provider.addListener({
                    val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(analyzer) { image ->
                        val link = image.use(::decode)?.let(PairLink::parse)
                        if (link != null) {
                            ContextCompat.getMainExecutor(ctx).execute {
                                if (!done) {
                                    done = true
                                    onLink(link)
                                }
                            }
                        }
                    }
                    provider.get().run {
                        unbindAll()
                        bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                    }
                }, ContextCompat.getMainExecutor(ctx))
            }
        },
    )
    DisposableEffect(Unit) {
        onDispose {
            if (provider.isDone) provider.get().unbindAll()
            analyzer.shutdown()
        }
    }
}

/** The text of a QR code in the frame, or null. Only the brightness plane is needed. */
private fun decode(image: ImageProxy): String? {
    val plane = image.planes[0]
    val bytes = ByteArray(plane.buffer.remaining()).also { plane.buffer.get(it) }
    val source = PlanarYUVLuminanceSource(bytes, plane.rowStride, image.height, 0, 0, image.width, image.height, false)
    return try {
        QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text
    } catch (_: ReaderException) {
        null
    }
}
