import SwiftUI

/// 时间框架选择器组件
struct TimeFrameSelectorView: View {
    @Binding var selectedTimeFrame: TimeFrame
    let onSelect: (TimeFrame) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Button(action: {
                    selectedTimeFrame = timeFrame
                    onSelect(timeFrame)
                }) {
                    Text(timeFrame.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selectedTimeFrame == timeFrame ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeFrame == timeFrame ? 
                                      Color.accentColor : 
                                      Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
    }
}

#Preview {
    @State var selected = TimeFrame.fifteenMin
    
    return VStack(spacing: 20) {
        TimeFrameSelectorView(selectedTimeFrame: $selected) { tf in
            print("Selected: \(tf)")
        }
    }
    .padding()
    .frame(width: 450)
    .background(Color(nsColor: .windowBackgroundColor))
}
