import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.modelKey) private var model = ClaudeMenuAnalyzer.defaultModel
    @AppStorage(AppSettings.bahtPer100YenKey) private var bahtPer100Yen = 0.0
    @AppStorage(AppSettings.stripsKey) private var strips = AppSettings.defaultStrips
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
                    HStack {
                        Text("100 เยน =")
                        TextField("เช่น 22.5", value: $bahtPer100Yen, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("บาท")
                    }
                } header: {
                    Text("อัตราแลกเปลี่ยน")
                } footer: {
                    Text("ใส่ 0 ถ้าไม่ต้องการแสดงราคาเป็นบาท")
                }

                Section {
                    Picker("ความละเอียดในการอ่าน", selection: $strips) {
                        Text("ปกติ").tag(1)
                        Text("ละเอียด").tag(2)
                        Text("ละเอียดมาก").tag(3)
                    }
                } footer: {
                    Text("แบ่งรูปเป็น 1, 2 หรือ 3 ส่วนก่อนส่งอ่าน ยิ่งแบ่งมาก ตัวหนังสือเล็กยิ่งอ่านออก แต่ค่า API ต่อรูปเพิ่มตามจำนวนส่วน")
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
