// TODO - Add search function

var listeners = []
var lastCategory = 1
var categories = []

function hideBody() {
    document.body.style.pointerEvents = "none";
    document.body.style.overflow = "hidden";
    document.body.style.display = "none";
}


function showBody() {
    document.body.style.pointerEvents = "auto";
    document.body.style.overflow = "auto";
    document.body.style.display = "block";
}

function removeListeners() {
    listeners.forEach(({ type, listener }) => {
        document.removeEventListener(type, listener);
    });
    listeners = [];
}

function simulatePress(id) {
    const button = document.getElementById(id);
    button.classList.add("simulate-hover");

    setTimeout(() => {
        button.classList.remove("simulate-hover");
        button.classList.add("simulate-active");
        setTimeout(() => {
            button.click();
            button.classList.remove("simulate-active");
        }, 100);
    }, 100);
}

function addListeners() {
    const keydownListener = (event) => {
        if (document.activeElement.tagName !== "INPUT") {
            if (event.key === "Escape" || event.key === "Backspace") {
                Post({}, "close");
            }
            else if (event.key === "Enter")
            {
                Post({}, "select")
            }
            else if (event.key === "ArrowRight")
            {
                simulatePress("next")
            }
            else if (event.key === " ")
            {
                Post({}, "centerEntity")
            }
            else if (event.key === "ArrowLeft")
            {
                simulatePress("prev")
            }
            else if (event.key === "w")
                {
                    simulatePress("move")
                }
            else if (event.key === "ArrowDown")
            {
                lastCategory -= 1
                if (lastCategory < 0) {lastCategory = categories.length - 1}
                simulatePress(categories[lastCategory])
            }
            else if (event.key === "ArrowUp")
            {
                lastCategory += 1
                if (lastCategory >=  categories.length) {lastCategory = 0}
                simulatePress(categories[lastCategory])
            }
        }
    };


    document.addEventListener("keydown", keydownListener);
    listeners.push({ type: "keydown", listener: keydownListener });

    const mousedownListener = (event) => {
        if (event.button === 0) {
            const target = event.target;
            if (!target.closest("input, button")) {
                Post({}, "clicked");
            }
        }
    };

    
    document.addEventListener("mousedown", mousedownListener);
    listeners.push({ type: "mousedown", listener: mousedownListener });


    const mousedownRightListener = (event) => {
        if (event.button === 2) {  // 2 corresponds to the right mouse button
            const target = event.target;
            if (!target.closest("input, button")) {
                Post({}, "tempDisable");
            }
        }
    };
    
    document.addEventListener("mousedown", mousedownRightListener);
    listeners.push({ type: "mousedown", listener: mousedownRightListener });
}

function close(temp) {
    removeListeners()
    if (!temp) { hideBody() }
}

function open() {
    addListeners()
    showBody()
}

function search() {
    let input = document.getElementById('search-input').value;
    if (input.length < 2) { return }
    Post({keyWord : input}, "search")
}

function createButton(index, buttonData, container) {
    let button = document.createElement("button");
    button.id = buttonData.name
    button.textContent = buttonData.label;
    container.appendChild(button);
    button.addEventListener('click', function() {
        this.blur();
        lastCategory = index - 1
        Post({
            index: index
        }, "category");
    });
}

function initButtons(id) {
    const button = document.getElementById(id);
    button.addEventListener("click", function() {
       this.blur();
       Post({}, id)
    });
}

window.addEventListener('message', function(event) {
    if (event.data.action === "show") {
        open()
    } else if (event.data.action === "close") {
        close()
    } else if (event.data.action === "tempClose") {
        close(true)
    } else if (event.data.action === "init") {
        const container = document.getElementById("button-categories");
        container.innerHTML = "";
        categories = event.data.data;

        for (let i = 0; i < categories.length - 1; i++) {
            createButton(i + 1,categories[i], container);
        }
        
    } else if (event.data.action === "gizmo") {
        var activated = event.data.activated;
        var helpElement = document.getElementById("gizmo-help");
        helpElement.style.display = activated && "block" || "none";
    }
});

function Post(data, action) {
    fetch(`https://${GetParentResourceName()}/`+action, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data)
    })
    .then(resp => resp.json())
    .catch(() => {
    });
}
  

initButtons("next")
initButtons("prev")
initButtons("move")
initButtons("close")
initButtons("select")