import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TestSequenceViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                stepsList
                if let currentStep = viewModel.sequenceManager.currentStep {
                    instructionCard(for: currentStep)
                } else if viewModel.sequenceManager.isCompleted {
                    successCard
                }
                controlButtons
            }
            .navigationTitle("Test Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Test Sequence Completed!", isPresented: $viewModel.showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("All \(viewModel.sequenceManager.steps.count) steps passed successfully.")
            }
            .onChange(of: viewModel.sequenceManager.isCompleted) { completed in
                if completed {
                    viewModel.showSuccessAlert = true
                }
            }
            .sheet(isPresented: $viewModel.showCameraSettingsSheet) {
                if let settings = viewModel.lastCameraSettings {
                    CameraSettingsView(settings: settings, isPresented: $viewModel.showCameraSettingsSheet)
                }
            }
        }
    }

    private var successCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Test Sequence Passed!")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.lastCameraSettings != nil {
                Button("View Camera Settings") {
                    viewModel.showCameraSettingsSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if viewModel.sequenceManager.isCompleted {
                    Text("All \(viewModel.sequenceManager.steps.count) steps completed!")
                        .font(.headline)
                        .foregroundColor(.green)
                } else if viewModel.sequenceManager.currentStepIndex >= 0 {
                    Text("Step \(min(viewModel.sequenceManager.currentStepIndex + 1, viewModel.sequenceManager.steps.count)) of \(viewModel.sequenceManager.steps.count)")
                        .font(.headline)
                } else {
                    Text("Ready to start")
                        .font(.headline)
                }
                Spacer()
                if viewModel.sequenceManager.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if viewModel.sequenceManager.failureReason != nil {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            Text("Last event: \(viewModel.lastEvent.isEmpty ? "-" : viewModel.lastEvent)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var stepsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.sequenceManager.steps) { step in
                    StepRow(step: step)
                        .id(step.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: viewModel.sequenceManager.currentStepIndex) { newIndex in
                if newIndex >= 0 && newIndex < viewModel.sequenceManager.steps.count {
                    withAnimation {
                        proxy.scrollTo(viewModel.sequenceManager.steps[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func instructionCard(for step: TestStep) -> some View {
        VStack(spacing: 8) {
            Text(step.title)
                .font(.headline)
            Text(step.instruction)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let reason = viewModel.sequenceManager.failureReason {
                Text("Error: \(reason)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if viewModel.sequenceManager.currentStepIndex < 0 {
                Button(action: viewModel.startSequence) {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.sequenceManager.isCompleted {
                Button(action: viewModel.resetSequence) {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if viewModel.sequenceManager.failureReason != nil {
                Button(action: viewModel.retryStep) {
                    Label("Retry", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: viewModel.resetSequence) {
                    Label("Reset", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                if viewModel.sequenceManager.currentStepName == .pulse {
                    Button(action: viewModel.skipCurrentStep) {
                        Label("Skip", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }

                Button(action: viewModel.stopMeasurement) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
    }
}

struct StepRow: View {
    let step: TestStep

    var body: some View {
        HStack {
            statusIcon
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text("\(step.id). \(step.title)")
                    .font(.body)
                    .fontWeight(step.status == .current ? .semibold : .regular)
                Text(step.expectedEvent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .background(step.status == .current ? Color.blue.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.gray)
        case .current:
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

struct CameraSettingsView: View {
    let settings: [String: Any]
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(settings.keys.sorted(), id: \.self) { key in
                    settingRow(for: key, value: settings[key])
                }
            }
            .listStyle(.plain)
            .navigationTitle("Camera Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private func settingRow(for key: String, value: Any?) -> some View {
        if let array = value as? NSArray, array.count > 0, array[0] is NSArray {
            DisclosureGroup {
                Text(formatArray(array))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            } label: {
                HStack {
                    Text(key).fontWeight(.semibold)
                    Spacer()
                    Text("[\(array.count) entries]")
                        .foregroundColor(.secondary)
                }
            }
        } else {
            HStack {
                Text(key).fontWeight(.semibold)
                Spacer()
                Text(formatScalar(value))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatScalar(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return "\(num)" }
        return "\(value)"
    }

    private func formatArray(_ array: NSArray) -> String {
        array.compactMap { element -> String? in
            guard let row = element as? NSArray else { return nil }
            return "[" + row.map { "\($0)" }.joined(separator: ", ") + "]"
        }.joined(separator: "\n")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
