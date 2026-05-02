(function bootstrapSnake(global) {
  var game = global.SnakeGame;
  var TICK_MS = 140;
  var DIRECTION_KEYS = {
    ArrowUp: "up",
    ArrowDown: "down",
    ArrowLeft: "left",
    ArrowRight: "right",
    w: "up",
    W: "up",
    a: "left",
    A: "left",
    s: "down",
    S: "down",
    d: "right",
    D: "right",
  };

  var board = document.getElementById("board");
  var score = document.getElementById("score");
  var status = document.getElementById("status");
  var restartButton = document.getElementById("restart-button");
  var pauseButton = document.getElementById("pause-button");
  var controlButtons = Array.prototype.slice.call(
    document.querySelectorAll("[data-direction]")
  );

  var state = game.createInitialState();
  var cells = [];
  var intervalId = null;

  function buildBoard(gridSize) {
    board.innerHTML = "";
    board.style.gridTemplateColumns = "repeat(" + gridSize + ", 1fr)";
    board.style.gridTemplateRows = "repeat(" + gridSize + ", 1fr)";
    cells = [];

    for (var y = 0; y < gridSize; y += 1) {
      for (var x = 0; x < gridSize; x += 1) {
        var cell = document.createElement("div");
        cell.className = "cell";
        board.appendChild(cell);
        cells.push(cell);
      }
    }
  }

  function indexFor(x, y, gridSize) {
    return y * gridSize + x;
  }

  function render() {
    var snakeKeys = new Set(
      state.snake.map(function toKey(segment) {
        return segment.x + ":" + segment.y;
      })
    );
    var head = state.snake[0];
    var foodKey = state.food ? state.food.x + ":" + state.food.y : null;

    for (var y = 0; y < state.gridSize; y += 1) {
      for (var x = 0; x < state.gridSize; x += 1) {
        var cell = cells[indexFor(x, y, state.gridSize)];
        var key = x + ":" + y;
        cell.className = "cell";

        if (snakeKeys.has(key)) {
          cell.classList.add("cell--snake");
        }

        if (head.x === x && head.y === y) {
          cell.classList.add("cell--head");
        } else if (foodKey === key) {
          cell.classList.add("cell--food");
        }
      }
    }

    score.textContent = String(state.score);

    if (state.isGameOver && state.didWin) {
      status.textContent = "You filled the board. Press restart or R to play again.";
      pauseButton.textContent = "Pause";
      return;
    }

    if (state.isGameOver) {
      status.textContent = "Game over. Press restart or R to try again.";
      pauseButton.textContent = "Pause";
      return;
    }

    if (!state.hasStarted) {
      status.textContent = "Use arrow keys or WASD to start.";
      pauseButton.textContent = "Pause";
      return;
    }

    if (state.isPaused) {
      status.textContent = "Paused. Press Space or Pause to continue.";
      pauseButton.textContent = "Resume";
      return;
    }

    status.textContent = "Keep going.";
    pauseButton.textContent = "Pause";
  }

  function sync(nextState) {
    state = nextState;
    render();
  }

  function startLoop() {
    if (intervalId !== null) {
      global.clearInterval(intervalId);
    }

    intervalId = global.setInterval(function onTick() {
      sync(game.advanceState(state));
    }, TICK_MS);
  }

  function changeDirection(direction) {
    sync(game.setDirection(state, direction));
  }

  function restart() {
    sync(game.createInitialState());
    board.focus();
  }

  document.addEventListener("keydown", function onKeyDown(event) {
    var direction = DIRECTION_KEYS[event.key];

    if (direction) {
      event.preventDefault();
      changeDirection(direction);
      return;
    }

    if (event.key === " " || event.key === "Spacebar") {
      event.preventDefault();
      sync(game.togglePause(state));
      return;
    }

    if (event.key === "r" || event.key === "R") {
      event.preventDefault();
      restart();
    }
  });

  restartButton.addEventListener("click", restart);
  pauseButton.addEventListener("click", function onPauseClick() {
    sync(game.togglePause(state));
  });

  controlButtons.forEach(function bindControl(button) {
    button.addEventListener("click", function onControlClick() {
      changeDirection(button.dataset.direction);
      board.focus();
    });
  });

  buildBoard(state.gridSize);
  startLoop();
  render();
})(window);
