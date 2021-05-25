import SwiftUI

struct SliderView: View {
    
    @State var value: Double = 0
    var label: String
    var minValue: Double
    var maxValue: Double
    
    var specifier: String = "%.1f"
    var divideBy: (Double, String) = (1.0, "")
    
    var body: some View {
        VStack {
            VStack {
                Slider(value: $value, in: minValue...maxValue, minimumValueLabel: Text("hoi"), maximumValueLabel: Text("hoimax"), label: { Text("naampie") })
                Slider(value: $value, in: minValue...maxValue)
                Text("\(label) \(value / divideBy.0, specifier: "\(specifier)")\(divideBy.1)")
            }
            Divider()
        }
    }
}

struct SliderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SliderView(label: "move speed", minValue: 0, maxValue: 10)
            SliderView(label: "turn speed", minValue: 0, maxValue: 2 * .pi, divideBy: (.pi, "π"))
            SliderView(label: "move speed", minValue: 0, maxValue: 10)
            SliderView(label: "move speed", minValue: 0, maxValue: 10)
            SliderView(label: "move speed", minValue: 0, maxValue: 10)
        }
    }
}
