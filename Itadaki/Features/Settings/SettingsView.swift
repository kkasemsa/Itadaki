import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.modelKey) private var model = ClaudeMenuAnalyzer.defaultModel
    @AppStorage(AppSettings.bahtPerYenKey) private var bahtPerYen = 0.0
    @AppStorage(AppSettings.sampleModeKey) private var sampleMode = false
    @State private var apiKey = ""
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text("เก็บใน Keychain ของเครื่องนี้เท่านั้น สร้าง key ได้ที่ platform.claude.com")
                }

                Section {
                    TextField(ClaudeMenuAnalyzer.defaultModel, text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("โมเดล")
                } footer: {
                    Text("ค่าเริ่มต้น \(ClaudeMenuAnalyzer.defaultModel)")
                }

                Section {
                    TextField("เช่น 0.23", value: $bahtPerYen, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("อัตราแลกเปลี่ยน (บาทต่อ 1 เยน)")
                } footer: {
                    Text("ใส่ 0 ถ้าไม่ต้องการแสดงราคาเป็นบาท")
                }

                Section {
                    Toggle("โหมดตัวอย่าง", isOn: $sampleMode)
                } footer: {
                    Text("แสดงเมนูตัวอย่างโดยไม่เรียก API ใช้ทดสอบหน้าจอ")
                }
            }
            .navigationTitle("ตั้งค่า")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { save() }
                }
            }
            .alert("บันทึก API key ไม่สำเร็จ", isPresented: $saveFailed) {
                Button("ตกลง", role: .cancel) {}
            }
            .onAppear { apiKey = KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "" }
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainStore.set(trimmed, for: KeychainStore.apiKeyAccount) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

#Preview {
    SettingsView()
}
