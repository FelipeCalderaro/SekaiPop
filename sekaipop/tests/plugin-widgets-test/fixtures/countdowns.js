.pragma library
function settings() {
    var d = new Date(), p = function (n) { return (n < 10 ? "0" : "") + n }
    function day(k) { var x = new Date(d.getFullYear(), d.getMonth(), d.getDate() + k); return x.getFullYear() + "-" + p(x.getMonth() + 1) + "-" + p(x.getDate()) }
    return { events: day(12) + " Project SEKAI 4th Anniversary\n" + day(1) + " 20:00 Live stream\n" + day(40) + " Concert\nnot a date\n" + (p(d.getMonth() + 1)) + "-" + p(d.getDate()) + " Mafuyu's birthday" }
}
