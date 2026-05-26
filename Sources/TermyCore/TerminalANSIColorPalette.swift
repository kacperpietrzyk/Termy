enum TerminalANSIColorPalette {
    static func indexedStyle(for index: Int) -> TerminalANSIStyle? {
        guard (0...255).contains(index) else { return nil }

        let baseColors: [(Int, Int, Int)] = [
            (0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0),
            (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
            (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0),
            (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)
        ]

        if index < baseColors.count {
            let color = baseColors[index]
            return .trueColor(red: color.0, green: color.1, blue: color.2)
        }

        if index <= 231 {
            let cubeIndex = index - 16
            return .trueColor(
                red: colorCubeComponent(cubeIndex / 36),
                green: colorCubeComponent((cubeIndex % 36) / 6),
                blue: colorCubeComponent(cubeIndex % 6)
            )
        }

        let value = 8 + ((index - 232) * 10)
        return .trueColor(red: value, green: value, blue: value)
    }

    private static func colorCubeComponent(_ value: Int) -> Int {
        value == 0 ? 0 : 55 + (value * 40)
    }
}
