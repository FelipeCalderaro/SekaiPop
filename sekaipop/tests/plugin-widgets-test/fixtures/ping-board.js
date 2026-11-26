.pragma library
// three hosts: a steady one, a jumpy one with losses, one that stopped answering; a finished speed test
function service(Qt) {
    var steady = [], jumpy = [], down = []
    for (var i = 0; i < 30; i++) {
        steady.push(11 + Math.sin(i / 3) * 2)
        jumpy.push(i % 7 === 3 ? null : 40 + (i * 37 % 60))
        down.push(i < 22 ? 24 + (i % 5) : null)
    }
    return {
        hosts: [{ address: "1.1.1.1", label: "Cloudflare" }, { address: "8.8.8.8", label: "Google" }, { address: "10.0.0.9", label: "NAS" }],
        samples: { "1.1.1.1": steady, "8.8.8.8": jumpy, "10.0.0.9": down },
        speedState: "done", speedDown: "312 Mbps", speedUp: "41 Mbps", speedAt: Date.now() - 240000,
        runSpeedTest: function () {}
    }
}
