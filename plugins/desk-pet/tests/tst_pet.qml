import QtQuick
import QtTest
import "../Pet.js" as PET

// qmltestrunner -platform offscreen -input plugins/desk-pet/tests
TestCase {
    name: "Pet"

    function inp(now, extra) {
        return Object.assign({ now: now, playing: false, idle: false, clicked: false, rnd: () => 0.9 }, extra || {})
    }

    function test_wanders() {
        let s = PET.start(0)
        compare(s.mode, "sit")
        s = PET.step(s, inp(1000))
        compare(s.mode, "sit", "still sitting until its time is up")
        s = PET.step(s, inp(2000))
        compare(s.mode, "walk")
        compare(s.target, 0.9)
        compare(s.facing, 1)
        compare(s.until, 2000 + PET.walkMs(0.5, 0.9))
        s = PET.step(s, inp(s.until))
        compare(s.mode, "sit", "arrived")
        compare(s.x, 0.9)
    }

    function test_no_shuffle_on_the_spot() {
        let s = { mode: "sit", x: 0.5, target: 0.5, until: 0, facing: 1 }
        s = PET.step(s, inp(0, { rnd: () => 0.55 }))
        verify(Math.abs(s.target - s.x) >= 0.15, "a walk goes somewhere")
    }

    function test_priorities() {
        let s = PET.start(0)
        compare(PET.step(s, inp(10, { playing: true })).mode, "dance")
        compare(PET.step(s, inp(10, { playing: true, idle: true })).mode, "sleep", "asleep beats dancing")
        const happy = PET.step(s, inp(10, { idle: true, clicked: true }))
        compare(happy.mode, "happy", "a click wakes it")
        compare(PET.step(happy, inp(500, { idle: true })).mode, "happy", "for a moment")
        compare(PET.step(happy, inp(2000, { idle: true })).mode, "sleep", "then back to sleep if you're still away")
    }

    function test_walk_interrupted_lands() {
        let s = { mode: "walk", x: 0.1, target: 0.8, until: 99999, facing: 1 }
        s = PET.step(s, inp(100, { playing: true }))
        compare(s.mode, "dance")
        compare(s.x, 0.8, "stops where the walk was going")
    }

    function test_back_to_wandering() {
        let s = { mode: "dance", x: 0.3, target: 0.3, until: 0, facing: 1 }
        s = PET.step(s, inp(100))
        compare(s.mode, "sit")
        compare(s.until, 1600)
    }

    function test_walk_time_and_mood() {
        compare(PET.walkMs(0, 1), 9000)
        compare(PET.walkMs(0.5, 0.52), 600, "a short step still takes a moment")
        compare(PET.mood("dance"), "♪")
        compare(PET.mood("walk"), "")
    }
}
