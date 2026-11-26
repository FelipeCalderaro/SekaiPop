import QtQuick
import QtTest
import "../Countdown.js" as CD

// qmltestrunner -platform offscreen -input plugins/countdowns/tests
TestCase {
    name: "Countdown"

    // Thu 26 Nov 2026, 10:00
    readonly property date now: new Date(2026, 10, 26, 10, 0, 0)

    function test_parse_lines() {
        const p = CD.parse("# comment\n\n2026-12-24 Christmas\n2026-11-27 20:00 Stream\n12-24 Yearly\n2026-02-30 Bad\nnope", now, false)
        compare(p.bad, 2, "a 30 February and a line with no date are not understood")
        compare(p.items.length, 3)
        compare(p.items[0].title, "Stream", "soonest first")
        compare(p.items[0].allDay, false)
        compare(p.items[1].title, "Christmas")
        compare(p.items[2].yearly, true)
        compare(p.items[2].date.getFullYear(), 2026)
    }

    function test_yearly_rolls_over() {
        const p = CD.parse("03-14 Birthday", now, false)
        compare(p.items[0].date.getFullYear(), 2027, "March has passed this year: next year's")
        const today = CD.parse("11-26 Today's", now, false)
        compare(today.items[0].date.getFullYear(), 2026, "today still counts")
    }

    function test_past_dropped_unless_asked() {
        compare(CD.parse("2026-11-20 Gone", now, false).items.length, 0)
        compare(CD.parse("2026-11-20 Gone", now, true).items.length, 1)
        compare(CD.parse("2026-11-26 Today", now, false).items.length, 1, "all day today is kept")
        compare(CD.parse("2026-11-26 09:00 Earlier", now, false).items.length, 0, "a time today that passed")
    }

    function test_labels_in_words() {
        compare(CD.label({ date: new Date(2026, 10, 26), allDay: true }, now).big, "Today")
        compare(CD.label({ date: new Date(2026, 10, 27), allDay: true }, now).words, "Tomorrow")
        compare(CD.label({ date: new Date(2026, 11, 8), allDay: true }, now).words, "In 12 days")
        compare(CD.label({ date: new Date(2026, 10, 26, 13, 30), allDay: false }, now).words, "In 3 h 30 min")
        compare(CD.label({ date: new Date(2026, 10, 26, 10, 20), allDay: false }, now).words, "In 20 min")
        const late = new Date(2026, 10, 26, 23, 0)
        compare(CD.label({ date: new Date(2026, 10, 27, 1, 0), allDay: true }, late).words, "Tomorrow", "days are calendar days")
    }

    function test_date_text() {
        compare(CD.dateText({ date: new Date(2026, 11, 24, 18, 30), allDay: false, yearly: false }, now, true), "Thu 24 Dec · 18:30")
        compare(CD.dateText({ date: new Date(2026, 11, 24, 18, 30), allDay: false, yearly: false }, now, false), "Thu 24 Dec · 6:30 PM")
        compare(CD.dateText({ date: new Date(2027, 0, 5), allDay: true, yearly: false }, now, true), "Tue 5 Jan 2027", "another year is said")
    }

    function test_progress() {
        compare(CD.progress({ date: new Date(2026, 10, 25) }, now, 30), 1)
        verify(CD.progress({ date: new Date(2027, 5, 1) }, now, 30) === 0, "further than the span: empty")
        const half = CD.progress({ date: new Date(now.getTime() + 15 * 86400000) }, now, 30)
        verify(Math.abs(half - 0.5) < 0.01)
    }
}
