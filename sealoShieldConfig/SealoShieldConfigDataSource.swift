import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom shield screen shown by iOS whenever the user tries to
/// open a monitored app.
///
/// Per `D5` the visual is Sealo teal + calm typography. Per `D7` the
/// copy never shames the user — Sealo is simply resurfacing. Per
/// `D3` the primary action is "Resurface" (dismiss, back to home);
/// tapping "Continue diving" is the dive-start signal handled by
/// `SealoShieldActionHandler`.
///
/// iOS invokes this class when rendering the shield overlay over
/// the target app. Must be a subclass of `ShieldConfigurationDataSource`,
/// which returns a `ShieldConfiguration` describing the UI.
final class SealoShieldConfigDataSource: ShieldConfigurationDataSource {

    // Teal tokens from D5 — kept literal here so the extension
    // doesn't need to compile in the full DesignSystem sources.
    private static let tealMid = UIColor(red: 27.0 / 255.0,
                                         green: 168.0 / 255.0,
                                         blue: 154.0 / 255.0,
                                         alpha: 1)

    // MARK: - ShieldConfigurationDataSource

    /// Called when a single Application token is being shielded.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    /// Called when an Application is shielded because its category
    /// is shielded (e.g., user picked "Social" in the
    /// FamilyActivityPicker).
    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    /// Called when a WebDomain is being shielded.
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    // MARK: - Shield UI

    /// The actual shield content. Single helper so all four overrides
    /// produce an identical UI — we don't differentiate based on
    /// category vs app vs domain.
    private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: Self.tealMid.withAlphaComponent(0.92),
            icon: nil,  // Sealo illustration is M1 territory; text-only for now
            title: ShieldConfiguration.Label(
                text: "Sealo is surfacing.",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Take a breath.",
                color: .white.withAlphaComponent(0.85)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Resurface",
                color: Self.tealMid
            ),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue diving",
                color: .white
            )
        )
    }
}
