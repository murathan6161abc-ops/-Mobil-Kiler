(function attachSnakeGame(global) {
  var GRID_SIZE = 16;
  var INITIAL_DIRECTION = "right";
  var DIRECTION_VECTORS = {
    up: { x: 0, y: -1 },
    down: { x: 0, y: 1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  };
  var OPPOSITES = {
    up: "down",
    down: "up",
    left: "right",
    right: "left",
  };

  function createInitialSnake() {
    return [
      { x: 2, y: 8 },
      { x: 1, y: 8 },
      { x: 0, y: 8 },
    ];
  }

  function cloneSegments(segments) {
    return segments.map(function clone(segment) {
      return { x: segment.x, y: segment.y };
    });
  }

  function createRng(seed) {
    var state = seed % 2147483647;

    if (state <= 0) {
      state += 2147483646;
    }

    return function nextRandom() {
      state = (state * 16807) % 2147483647;
      return (state - 1) / 2147483646;
    };
  }

  function pointsEqual(a, b) {
    return a.x === b.x && a.y === b.y;
  }

  function isOutOfBounds(point, gridSize) {
    return point.x < 0 || point.y < 0 || point.x >= gridSize || point.y >= gridSize;
  }

  function collidesWithSnake(point, snake) {
    return snake.some(function compare(segment) {
      return pointsEqual(segment, point);
    });
  }

  function getNextDirection(currentDirection, requestedDirection) {
    if (!requestedDirection || !DIRECTION_VECTORS[requestedDirection]) {
      return currentDirection;
    }

    if (OPPOSITES[currentDirection] === requestedDirection) {
      return currentDirection;
    }

    return requestedDirection;
  }

  function getNextHead(head, direction) {
    var vector = DIRECTION_VECTORS[direction];
    return {
      x: head.x + vector.x,
      y: head.y + vector.y,
    };
  }

  function getEmptyCells(gridSize, snake) {
    var occupied = new Set(
      snake.map(function toKey(segment) {
        return segment.x + ":" + segment.y;
      })
    );
    var cells = [];

    for (var y = 0; y < gridSize; y += 1) {
      for (var x = 0; x < gridSize; x += 1) {
        var key = x + ":" + y;
        if (!occupied.has(key)) {
          cells.push({ x: x, y: y });
        }
      }
    }

    return cells;
  }

  function placeFood(gridSize, snake, random) {
    var cells = getEmptyCells(gridSize, snake);

    if (cells.length === 0) {
      return null;
    }

    var index = Math.floor(random() * cells.length);
    return cells[index];
  }

  function createInitialState(options) {
    var config = options || {};
    var gridSize = config.gridSize || GRID_SIZE;
    var random = config.random || createRng(Date.now());
    var snake = cloneSegments(config.snake || createInitialSnake());

    return {
      gridSize: gridSize,
      snake: snake,
      direction: config.direction || INITIAL_DIRECTION,
      pendingDirection: config.direction || INITIAL_DIRECTION,
      food: config.food || placeFood(gridSize, snake, random),
      score: 0,
      isGameOver: false,
      didWin: false,
      isPaused: false,
      hasStarted: false,
      random: random,
    };
  }

  function setDirection(state, requestedDirection) {
    if (state.isGameOver) {
      return state;
    }

    return {
      gridSize: state.gridSize,
      snake: cloneSegments(state.snake),
      direction: state.direction,
      pendingDirection: getNextDirection(state.direction, requestedDirection),
      food: state.food ? { x: state.food.x, y: state.food.y } : null,
      score: state.score,
      isGameOver: state.isGameOver,
      didWin: state.didWin,
      isPaused: state.isPaused,
      hasStarted: true,
      random: state.random,
    };
  }

  function togglePause(state) {
    if (state.isGameOver || !state.hasStarted) {
      return state;
    }

    return {
      gridSize: state.gridSize,
      snake: cloneSegments(state.snake),
      direction: state.direction,
      pendingDirection: state.pendingDirection,
      food: state.food ? { x: state.food.x, y: state.food.y } : null,
      score: state.score,
      isGameOver: state.isGameOver,
      didWin: state.didWin,
      isPaused: !state.isPaused,
      hasStarted: state.hasStarted,
      random: state.random,
    };
  }

  function advanceState(state) {
    if (state.isGameOver || state.isPaused || !state.hasStarted) {
      return state;
    }

    var direction = getNextDirection(state.direction, state.pendingDirection);
    var head = state.snake[0];
    var nextHead = getNextHead(head, direction);
    var grew = state.food && pointsEqual(nextHead, state.food);
    var bodyToCheck = grew ? state.snake : state.snake.slice(0, -1);

    if (isOutOfBounds(nextHead, state.gridSize) || collidesWithSnake(nextHead, bodyToCheck)) {
      return {
        gridSize: state.gridSize,
        snake: cloneSegments(state.snake),
        direction: direction,
        pendingDirection: direction,
        food: state.food ? { x: state.food.x, y: state.food.y } : null,
        score: state.score,
        isGameOver: true,
        didWin: false,
        isPaused: false,
        hasStarted: true,
        random: state.random,
      };
    }

    var nextSnake = [nextHead].concat(cloneSegments(state.snake));

    if (!grew) {
      nextSnake.pop();
    }

    var food = state.food;
    var score = state.score;

    if (grew) {
      score += 1;
      food = placeFood(state.gridSize, nextSnake, state.random);
    }

    return {
      gridSize: state.gridSize,
      snake: nextSnake,
      direction: direction,
      pendingDirection: direction,
      food: food ? { x: food.x, y: food.y } : null,
      score: score,
      isGameOver: food === null && grew,
      didWin: food === null && grew,
      isPaused: false,
      hasStarted: true,
      random: state.random,
    };
  }

  global.SnakeGame = {
    GRID_SIZE: GRID_SIZE,
    createRng: createRng,
    createInitialState: createInitialState,
    setDirection: setDirection,
    togglePause: togglePause,
    advanceState: advanceState,
    placeFood: placeFood,
    collidesWithSnake: collidesWithSnake,
    isOutOfBounds: isOutOfBounds,
    getNextDirection: getNextDirection,
  };
})(window);
