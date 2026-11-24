import SwiftUI
import UIKit

/// A box drawn over a zoomable image, e.g. where one dish is printed on the page.
struct ImageBox: Identifiable, Equatable {
    let id: UUID
    let rect: NormalizedRect
}

/// Full-screen image viewer with pinch-to-zoom, pan and double-tap. When a highlight
/// is given, it opens already zoomed in around that box.
struct ImageZoomScreen: View {
    let image: UIImage
    private let boxes: [ImageBox]
    @Environment(\.dismiss) private var dismiss
    /// Fixed id for the single highlight, so re-creating this view never looks like a
    /// new selection.
    private static let highlightID = UUID()

    init(image: UIImage, highlight: NormalizedRect? = nil) {
        self.image = image
        self.boxes = highlight.map { [ImageBox(id: Self.highlightID, rect: $0)] } ?? []
    }

    var body: some View {
        ZoomableImage(image: image, boxes: boxes, selection: boxes.first?.id, focusOnAppear: true)
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

/// Zoomable image with optional boxes. The selected box is drawn strongly, the rest
/// faintly; tapping a box reports it through `onSelect`.
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    var boxes: [ImageBox] = []
    var selection: UUID?
    /// Open zoomed in on the selected box instead of showing the whole image.
    var focusOnAppear = false
    var background: UIColor = .black
    var onSelect: ((UUID) -> Void)?

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView(image: image, boxes: boxes, selection: selection, focusOnAppear: focusOnAppear)
        view.backgroundColor = background
        view.onSelect = onSelect
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.onSelect = onSelect
        view.backgroundColor = background
        view.setBoxes(boxes)
        view.select(selection, animated: true)
    }
}

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    var onSelect: ((UUID) -> Void)?

    private let imageView: UIImageView
    private var boxes: [ImageBox]
    private var boxViews: [UUID: UIView] = [:]
    private var selectedID: UUID?
    private let focusOnAppear: Bool
    private var laidOutSize = CGSize.zero
    private var didInitialZoom = false

    init(image: UIImage, boxes: [ImageBox], selection: UUID?, focusOnAppear: Bool) {
        self.imageView = UIImageView(image: image)
        self.boxes = []
        self.selectedID = selection
        self.focusOnAppear = focusOnAppear
        super.init(frame: .zero)
        delegate = self
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast

        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        contentSize = image.size
        setBoxes(boxes)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Boxes

    func setBoxes(_ newBoxes: [ImageBox]) {
        guard newBoxes != boxes else { return }
        boxes = newBoxes
        boxViews.values.forEach { $0.removeFromSuperview() }
        boxViews = [:]
        let size = imageView.bounds.size
        for box in newBoxes {
            let view = UIView(
                frame: CGRect(
                    x: box.rect.x * size.width, y: box.rect.y * size.height,
                    width: box.rect.width * size.width, height: box.rect.height * size.height
                ).insetBy(dx: -6, dy: -6))
            view.layer.cornerRadius = 6
            view.isUserInteractionEnabled = false
            imageView.addSubview(view)
            boxViews[box.id] = view
        }
        styleBoxes()
    }

    /// Marks a box as selected. When the change comes from outside (not from a tap on
    /// this view) the image scrolls and zooms so the box is in view.
    func select(_ id: UUID?, animated: Bool) {
        guard id != selectedID else { return }
        selectedID = id
        styleBoxes()
        if let id, didInitialZoom { focus(on: id, animated: animated) }
    }

    private func styleBoxes() {
        let accent = UIColor(Theme.accent)
        let scale = max(zoomScale, 0.01)
        for (id, view) in boxViews {
            let isSelected = id == selectedID
            view.layer.borderColor = accent.withAlphaComponent(isSelected ? 1 : 0.45).cgColor
            // Keep borders a constant width on screen at any zoom level.
            view.layer.borderWidth = (isSelected ? 3 : 1.2) / scale
            view.backgroundColor = accent.withAlphaComponent(isSelected ? 0.16 : 0.03)
        }
        if let selectedID, let view = boxViews[selectedID] { imageView.bringSubviewToFront(view) }
    }

    private func focus(on id: UUID, animated: Bool) {
        guard let frame = boxViews[id]?.frame else { return }
        // Close enough to read the item, with its neighbours for context.
        let area = frame.insetBy(dx: -frame.width * 1.5, dy: -frame.height * 0.6)
        zoom(to: area.intersection(imageView.bounds), animated: animated)
    }

    // MARK: Layout and zooming

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
                if focusOnAppear, let selectedID { focus(on: selectedID, animated: false) }
            }
            styleBoxes()
        }
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        styleBoxes()
        centerContent()
    }

    private func centerContent() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    // MARK: Gestures

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        // Boxes can overlap; prefer the smallest one under the finger.
        let hit = boxes
            .filter { boxViews[$0.id]?.frame.contains(point) == true }
            .min { $0.rect.area < $1.rect.area }
        guard let hit else { return }
        // Selected here first, so the echo from SwiftUI does not move the image.
        selectedID = hit.id
        styleBoxes()
        onSelect?(hit.id)
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
