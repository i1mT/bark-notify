import Darwin
import NotifySupport

@main
enum NotifyMain {
    static func main() async {
        Darwin.exit(Int32(await NotifyRunner.run()))
    }
}
