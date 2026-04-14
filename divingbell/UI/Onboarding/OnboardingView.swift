import SwiftUI
import FamilyControls

/// M3 onboarding flow.
///
/// Steps:
/// 1. Explain the diving-bell metaphor briefly.
/// 2. Request Family Controls authorization (system dialog).
/// 3. Show `FamilyActivityPicker` to choose which SNS apps to monitor.
/// 4. Persist the selection to `SharedDefaults`.
/// 5. Start monitoring via `RealScreenTimeService`.
///
/// Design tokens are hardcoded teal for M3; M1 will retrofit them.
/// Per D6, app icons from the selection appear only here (in the
/// picker) and are not shown on the dashboard or Dynamic Island.
struct OnboardingView: View {
    @Binding var isOnboarded: Bool
    @State private var step: OnboardingStep = .welcome
    @State private var selection = FamilyActivitySelection()
    @State private var errorMessage: String?

    private let screenTimeService = RealScreenTimeService()

    enum OnboardingStep {
        case welcome
        case authorize
        case pickApps
        case configure
    }

    var body: some View {
        VStack(spacing: 32) {
            switch step {
            case .welcome:
                welcomeStep
            case .authorize:
                authorizeStep
            case .pickApps:
                pickAppsStep
            case .configure:
                configureStep
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
    }

    // MARK: - Steps

    @ViewBuilder
    private var welcomeStep: some View {
        Spacer()
        VStack(spacing: 16) {
            OxygenTankGauge(fill: 1.0)
                .frame(width: 200, height: 90)

            Text("divingbell")
                .font(.largeTitle.weight(.bold))

            Text("Track your time in social media like a diver tracks oxygen. Set a daily budget, and divingbell enforces it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        Spacer()
        Button("Get started") {
            step = .authorize
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 27/255, green: 168/255, blue: 154/255))
    }

    @ViewBuilder
    private var authorizeStep: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(.teal)

            Text("Screen Time access")
                .font(.title2.weight(.semibold))

            Text("divingbell needs Screen Time permission to monitor which apps you use and enforce your dive budget. This data stays on your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        Spacer()
        Button("Allow Screen Time access") {
            Task {
                do {
                    try await screenTimeService.requestAuthorization()
                    errorMessage = nil
                    step = .pickApps
                } catch {
                    errorMessage = "Authorization failed: \(error.localizedDescription)"
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 27/255, green: 168/255, blue: 154/255))
    }

    @ViewBuilder
    private var pickAppsStep: some View {
        VStack(spacing: 16) {
            Text("Choose apps to monitor")
                .font(.title2.weight(.semibold))

            Text("Select the SNS apps you want to track. They all share one oxygen tank.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            FamilyActivityPicker(selection: $selection)
                .frame(maxHeight: 400)

            Button("Continue") {
                persistSelection()
                step = .configure
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 27/255, green: 168/255, blue: 154/255))
            .disabled(selection.applicationTokens.isEmpty
                      && selection.categoryTokens.isEmpty)
        }
    }

    @ViewBuilder
    private var configureStep: some View {
        Spacer()
        VStack(spacing: 16) {
            OxygenTankGauge(fill: 1.0)
                .frame(width: 160, height: 72)

            Text("You're ready to dive")
                .font(.title2.weight(.semibold))

            Text("Your tank is full. divingbell is now monitoring your selected apps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        Spacer()
        Button("Start diving") {
            Task {
                do {
                    try await screenTimeService.startMonitoring()
                    errorMessage = nil
                    isOnboarded = true
                } catch {
                    errorMessage = "Failed to start monitoring: \(error.localizedDescription)"
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 27/255, green: 168/255, blue: 154/255))
    }

    // MARK: - Helpers

    private func persistSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            SharedDefaults.saveAppSelection(data)
        }
    }
}
