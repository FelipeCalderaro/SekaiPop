import QtQuick
import QtTest
import "../../modules/common/functions/IdleSteps.js" as IS

// /usr/lib/qt6/bin/qmltestrunner -platform offscreen -input tests/quick-idle-test   (from sekaipop/)
TestCase {
    name: "IdleSteps"

    function test_steps() {
        compare(IS.step(IS.LOCK_STEPS, 5, 1), 10)
        compare(IS.step(IS.LOCK_STEPS, 5, -1), 3)
        compare(IS.step(IS.LOCK_STEPS, 0, -1), 0, "Never is the floor")
        compare(IS.step(IS.LOCK_STEPS, 120, 1), 120, "the top stays")
        compare(IS.step(IS.LOCK_STEPS, 7, 1), 10, "an odd value from Settings goes forward to the next step")
        compare(IS.step(IS.LOCK_STEPS, 7, -1), 5)
        compare(IS.step(IS.SLEEP_STEPS, 0, 1), 5)
        compare(IS.stepsFor("idle.sleep"), IS.SLEEP_STEPS)
        compare(IS.stepsFor("idle.lock"), IS.LOCK_STEPS)
    }

    function test_labels() {
        compare(IS.label(0), "Never")
        compare(IS.label(5), "5 min")
        compare(IS.label(60), "1 h")
        compare(IS.label(90), "1 h 30 min")
    }

    function test_summary_is_the_first_thing() {
        compare(IS.summary(5, 10, 15, "suspend"), "Lock 5 min")
        compare(IS.summary(0, 10, 15, "suspend"), "Screen off 10 min")
        compare(IS.summary(0, 0, 30, "hibernate"), "Hibernate 30 min")
        compare(IS.summary(0, 0, 0, "suspend"), "Never")
        compare(IS.summary(20, 10, 0, "suspend"), "Screen off 10 min")
    }

    function test_order_notes() {
        compare(IS.orderNote(5, 10, 15, "suspend"), "")
        compare(IS.orderNote(30, 10, 15, "suspend"), "It sleeps before it locks; the lock comes when it wakes.")
        compare(IS.orderNote(5, 20, 15, "hibernate"), "It hibernates before the screen would turn off.")
        compare(IS.orderNote(5, 20, 0, "suspend"), "", "never sleeping: no conflict")
    }
}
