import UIKit
import UserNotifications
import UserNotificationsUI
import os

/// UIKit entry point hosted by the system when a matching notification is expanded.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let stack = UIStackView()
    private let dayLabel = UILabel()
    private let areaLabel = UILabel()
    private let sampleLabel = UILabel()
    private let logger = Logger(subsystem: "com.WasteWise.sana.Wastewise.CollectionNotificationContent", category: "presentation")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemGroupedBackground
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20)
        ])
        let heading = UILabel()
        heading.text = "WasteWise"
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.textColor = .systemGreen
        heading.accessibilityIdentifier = "wastewiseExpandedNotification"
        stack.addArrangedSubview(heading)
        // Reuse the existing empty-bin mascot, excluding its countdown calendar entirely.
        if let source = UIImage(named: "Mascot"), let image = source.cgImage?.cropping(to: CGRect(x: 0, y: 340, width: 675, height: 780)) {
            let mascot = UIImageView(image: UIImage(cgImage: image))
            mascot.contentMode = .scaleAspectFit
            mascot.heightAnchor.constraint(equalToConstant: 100).isActive = true
            mascot.isAccessibilityElement = false
            stack.addArrangedSubview(mascot)
        }
        sampleLabel.text = "Development sample"
        sampleLabel.textColor = .secondaryLabel
        sampleLabel.isHidden = true
        stack.addArrangedSubview(sampleLabel)
        dayLabel.font = .preferredFont(forTextStyle: .title2)
        dayLabel.accessibilityIdentifier = "usualCollectionWeekday"
        stack.addArrangedSubview(dayLabel)
        stack.addArrangedSubview(areaLabel)
        let detail = UILabel()
        detail.text = CollectionReminderContent.caveat
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = .secondaryLabel
        stack.addArrangedSubview(detail)
        for case let label as UILabel in stack.arrangedSubviews {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        dayLabel.text = "Usual collection day"
        areaLabel.text = "Open WasteWise to check your collection information."
    }

    func didReceive(_ notification: UNNotification) {
        loadViewIfNeeded()
        let payload = notification.request.content.userInfo
        if let information = CollectionReminderContent(userInfo: payload) {
            dayLabel.text = "Usual collection day\n\(information.weekdayName)"
            areaLabel.text = "Recycling area: \(information.recyclingArea)"
        } else {
            dayLabel.text = "Usual collection day"
            areaLabel.text = "Open WasteWise to check your collection information."
        }
        sampleLabel.isHidden = payload["wastewise.sample"] as? Bool != true
        view.setNeedsLayout()
        logger.info("Custom WasteWise notification content received and displayed")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = max(view.bounds.width - 40, 1)
        let size = stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        preferredContentSize = CGSize(width: view.bounds.width, height: size.height + 40)
    }
}
