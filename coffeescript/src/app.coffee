class PomodoroTimer
    constructor: (@workDuration = 10, @breakDuration = 5) ->
        # Инициализация состояния таймера
        @timeLeft = @workDuration
        @isRunning = false
        @isWorkSession = true
        @intervalId = null
        @completedSessions = 0
        
        # Получение элементов DOM
        @elements =
            display: document.getElementById 'timer-display'
            sessionType: document.getElementById 'session-type'
            sessionCounter: document.getElementById 'session-counter'
            sessionHistory: document.getElementById 'session-history'
            progressBar: document.getElementById 'progress-bar'
            startButton: document.getElementById 'start-button'
            pauseButton: document.getElementById 'pause-button'
            resetButton: document.getElementById 'reset-button'
            notificationSound: document.getElementById 'notification-sound'
        
        # Загрузка данных из LocalStorage
        @loadFromStorage()
        
        # Назначение обработчиков событий
        @bindEvents()
        
        # Первоначальное обновление интерфейса
        @updateDisplay()
    
    bindEvents: ->
        # Используем стрелочные функции для сохранения контекста
        @elements.startButton.addEventListener 'click', => @start()
        @elements.pauseButton.addEventListener 'click', => @pause()
        @elements.resetButton.addEventListener 'click', => @reset()
    
    start: ->
        return if @isRunning
        
        @isRunning = true
        @updateButtons()
        
        @intervalId = setInterval =>
            @timeLeft -= 1
            @updateDisplay()
            
            if @timeLeft <= 0
                @completeSession()
        , 1000
    
    pause: ->
        return unless @isRunning
        
        @isRunning = false
        clearInterval @intervalId
        @updateButtons()
    
    reset: ->
        @isRunning = false
        clearInterval @intervalId if @intervalId
        
        if @isWorkSession
            @timeLeft = @workDuration
        else
            @timeLeft = @breakDuration
            
        @updateDisplay()
        @updateButtons()
    
    completeSession: ->
        @isRunning = false
        clearInterval @intervalId if @intervalId
        
        # Воспроизведение звука
        @playNotificationSound()
        
        # Сохранение сессии
        @saveSession()
        
        # Переключение типа сессии
        @isWorkSession = not @isWorkSession
        
        if @isWorkSession
            @timeLeft = @workDuration
        else
            @timeLeft = @breakDuration
            # Увеличиваем счетчик только после завершения рабочей сессии
            @completedSessions += 1
            @elements.sessionCounter.textContent = @completedSessions
        
        @updateDisplay()
        @updateButtons()
        @saveToStorage()
    
    updateDisplay: ->
        minutes = Math.floor(@timeLeft / 60)
        seconds = @timeLeft % 60
        
        # Форматирование времени
        formattedTime = "#{minutes.toString().padStart(2, '0')}:#{seconds.toString().padStart(2, '0')}"
        @elements.display.textContent = formattedTime
        
        # Обновление текста сессии
        sessionText = if @isWorkSession then 'Рабочая сессия' else 'Перерыв'
        @elements.sessionType.textContent = sessionText
        
        # Обновление прогресс-бара
        totalTime = if @isWorkSession then @workDuration else @breakDuration
        progress = ((totalTime - @timeLeft) / totalTime) * 100
        @elements.progressBar.style.width = "#{progress}%"
        
        # Изменение цвета в зависимости от оставшегося времени
        if @timeLeft < 60 and @isRunning
            @elements.display.style.color = '#f44336'
        else if @isWorkSession
            @elements.display.style.color = '#333'
        else
            @elements.display.style.color = '#ff9800'
    
    updateButtons: ->
        @elements.startButton.disabled = @isRunning
        @elements.pauseButton.disabled = not @isRunning
        @elements.startButton.textContent = if @isRunning then 'Запущен' else 'Старт'
    
    playNotificationSound: ->
        try
            @elements.notificationSound.currentTime = 0
            @elements.notificationSound.play().catch (error) ->
                console.log 'Автовоспроизведение звука заблокировано:', error
        catch error
            console.log 'Ошибка воспроизведения звука:', error
    
    saveSession: ->
        sessionType = if @isWorkSession then 'work' else 'break'
        duration = if @isWorkSession then @workDuration else @breakDuration
        
        sessionData =
            type: sessionType
            duration: duration
            endTime: new Date().toISOString()
            timestamp: Date.now()
        
        # Добавление в историю
        @addSessionToHistory sessionData
    
    addSessionToHistory: (sessionData) ->
        sessionItem = document.createElement 'div'
        sessionItem.className = "session-item session-#{sessionData.type}"
        
        typeText = if sessionData.type is 'work' then 'Работа' else 'Перерыв'
        durationMinutes = Math.floor(sessionData.duration / 60)
        time = new Date(sessionData.endTime).toLocaleTimeString 'ru-RU',
            hour: '2-digit'
            minute: '2-digit'
        
        sessionItem.innerHTML = """
            <div>
                <span class="session-time">#{time}</span>
                <div>#{typeText}</div>
            </div>
            <span class="session-duration">#{durationMinutes} мин</span>
        """
        
        # Добавляем в начало
        @elements.sessionHistory.insertBefore sessionItem, @elements.sessionHistory.firstChild
        
        # Ограничиваем историю 50 элементами
        if @elements.sessionHistory.children.length > 50
            @elements.sessionHistory.removeChild @elements.sessionHistory.lastChild
    
    saveToStorage: ->
        storageData =
            completedSessions: @completedSessions
            history: @getHistoryData()
        
        try
            localStorage.setItem 'pomodoroData', JSON.stringify storageData
        catch error
            console.log 'Ошибка сохранения в LocalStorage:', error
    
    loadFromStorage: ->
        try
            data = localStorage.getItem 'pomodoroData'
            return unless data
            
            parsedData = JSON.parse data
            @completedSessions = parsedData.completedSessions ? 0
            @elements.sessionCounter.textContent = @completedSessions
            
            # Восстановление истории
            if parsedData.history?
                for session in parsedData.history
                    @addSessionToHistory session
        catch error
            console.log 'Ошибка загрузки из LocalStorage:', error
    
    getHistoryData: ->
        historyItems = @elements.sessionHistory.querySelectorAll '.session-item'
        historyData = []
        
        for item in historyItems
            timeElement = item.querySelector '.session-time'
            typeElement = item.querySelector 'div'
            durationElement = item.querySelector '.session-duration'
            
            continue unless timeElement and typeElement and durationElement
            
            historyData.push
                type: if typeElement.textContent.includes('Работа') then 'work' else 'break'
                duration: parseInt(durationElement.textContent) * 60
                endTime: new Date().toDateString() + ' ' + timeElement.textContent
        
        historyData

# Инициализация приложения после загрузки DOM
document.addEventListener 'DOMContentLoaded', ->
    window.pomodoroTimer = new PomodoroTimer()
    
    # Добавляем информацию о сборке
    console.log '🍅 Pomodoro Tracker запущен!'
    console.log 'Собрано с CoffeeScript', Date.now()