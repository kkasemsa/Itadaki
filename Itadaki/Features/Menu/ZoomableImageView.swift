import SwiftUI
import UIKit

/// Full-screen image viewer with pinch-to-zoom, pan and double-tap. When a highlight
/// is given, it opens already zoomed in around that box.
struct ImageZoomScreen: View {
    let image: UIImage
    var highlight: NormalizedRect?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZoomableImage(image: image, highlight: highlight)
            .ignoresSafeArea()
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .accessibilityLabel("ปิด")
                .padding(16)
            }
            .statusBarHidden()
    }
}

struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    let highlight: NormalizedRect?

    func makeUIView(context: Context) -> ZoomScrollView {
        ZoomScrollView(image: image, highlight: highlight)
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {}
}

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView: UIImageView
    private let highlightView = UIView()
    private let highlight: NormalizedRect?
    private var laidOutSize = CGSize.zero
    private var didInitialZoom = false

    init(image: UIImage, highlight: NormalizedRect?) {
        self.imageView = UIImageView(image: image)
        self.highlight = highlight
        super.init(frame: .zero)
        delegate = self
        backgroundColor = .black
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast

        imageView.frame = CGRect(origin: .zero, size: image.size)
        addSubview(imageView)
        contentSize = image.size

        if let highlight {
            highlightView.frame = CGRect(
                x: highlight.x * image.size.width, y: highlight.y * image.size.height,
                width: highlight.width * image.size.width, height: highlight.height * image.size.height
            ).insetBy(dx: -6, dy: -6)
            highlightView.layer.borderColor = UIColor(Theme.accent).cgColor
            highlightView.layer.cornerRadius = 6
            highlightView.backgroundColor = UIColor(Theme.accent).withAlphaComponent(0.12)
            highlightView.isUserInteractionEnabled = false
            imageView.addSubview(highlightView)
        }

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if bounds.size != laidOutSize {
            laidOutSize = bounds.size
            let imageSize = imageView.bounds.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let fit = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
            minimumZoomScale = fit
            maximumZoomScale = max(fit * 8, 2)
            if didInitialZoom {
                zoomScale = max(zoomScale, fit)
            } else {
                didInitialZoom = true
                zoomScale = fit
                if highlight != nil {
                    // Start close enough to read the item, with its neighbours for context.
                    let focus = highlightView.frame.insetBy(
                        dx: -highlightView.frame.width * 1.5, dy: -highlightView.frame.height * 0.6)
                    zoom(to: focus.intersection(imageView.bounds), animated: false)
                }
            }
            updateHighlightBorder()
        }
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateHighlightBorder()
        centerContent()
    }

    /// Keeps the border about 3 points wide on screen at any zoom level.
    private func updateHighlightBorder() {
        highlightView.layer.borderWidth = 3 / max(zoomScale, 0.01)
    }

    private func centerContent() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.5 {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let scale = min(maximumZoomScale, minimumZoomScale * 3)
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(
                to: CGRect(
                    x: point.x - size.width / 2, y: point.y - size.height / 2,
                    width: size.width, height: size.height),
                animated: true)
        }
    }
}
