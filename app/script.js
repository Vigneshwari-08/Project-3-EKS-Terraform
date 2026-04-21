function updateText() {
    const version = document.getElementById("version");
    const time = new Date().toLocaleTimeString();

    version.innerText = "🚀 Deployment verified at: " + time;
}