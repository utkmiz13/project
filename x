<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gram Sahayak AI - Rural Assistant</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        @keyframes fade-in {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in {
            animation: fade-in 0.3s ease-out;
        }
        .progress-bar {
            transition: width 0.3s ease;
        }
    </style>
</head>
<body class="bg-green-50 text-gray-900 dark:bg-gray-900 dark:text-gray-100 min-h-screen flex flex-col">
    <!-- State Management -->
    <script>
        // ===== STATE VARIABLES =====
        const state = {
            messages: [],
            input: '',
            topic: 'all',
            lang: 'en-IN',
            isOnline: navigator.onLine,
            isTyping: false,
            isListening: false,
            showWeather: false,
            showEmergency: false,
            showSettings: false,
            showInfo: false,
            darkMode: false,
            autoTTS: false,
            soundOn: true,
            saverMode: false,
            msgCount: 0,
            totalBytes: 0,
            sessionTime: '0:00',
            weather: null,
            isFirstMessage: true,
            progress: 0,
            sessionStart: Date.now(),
            recognition: null
        };

        // ===== KNOWLEDGE BASE =====
        const KB = {
            agriculture: [
                {
                    kw: ["rice", "paddy", "dhaan", "sowing rice", "transplant"],
                    a: `🌾 <b>Rice / Paddy Farming — Complete Guide</b><br><br>
<b>Varieties:</b> IR-64, Swarna, MTU-1010, BPT-5204 (Sona Masoori), PR-106, HUR-36<br>
<b>Sowing Season:</b> Kharif (June–July) | Rabi (Nov–Dec in some regions)<br>
<b>Nursery:</b> Sow in nursery bed → transplant 25–30 day old seedlings<br>
<b>Spacing:</b> 20×15 cm for higher yield | Direct seeding also works<br>
<b>Water:</b> Keep 5 cm water up to panicle initiation; drain before harvest<br>
<b>Fertilizer (per acre):</b> Urea 50 kg + DAP 25 kg + MOP 17 kg<br>&nbsp;&nbsp;Split Urea: Basal(¼) + Tillering(¼) + Panicle(½)<br>
<b>Diseases:</b> Blast (spray Tricyclazole 6g/10L) | BLB (spray Copper Oxychloride)<br>
<b>Pests:</b> Stem Borer (Chlorpyrifos 2ml/L) | Brown Planthopper (Imidacloprid)<br>
<b>Yield:</b> 20–30 qt/acre (improved varieties up to 40 qt/acre)<br>
<b>Post-harvest:</b> Dry to 14% moisture before storage`
                },
                // ... (other agriculture entries)
            ],
            // ... (other categories)
        };

        // ===== UTILITY FUNCTIONS =====
        function getTime() {
            return new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
        }

        function stripTags(html) {
            const div = document.createElement('div');
            div.innerHTML = html;
            return div.textContent || div.innerText || '';
        }

        function formatBytes(bytes) {
            if (bytes < 1024) return bytes + ' B';
            if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
            return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
        }

        function getChips(t) {
            const chips = {
                all: ['Rice farming', 'Cow care', 'PM KISAN', 'MUDRA loan'],
                agriculture: ['Soil health tips', 'Drip irrigation', 'Pest control', 'Organic farming'],
                // ... other topics
            };
            return chips[t] || chips.all;
        }

        function speak(text) {
            if ('speechSynthesis' in window && state.autoTTS) {
                window.speechSynthesis.cancel();
                const utt = new SpeechSynthesisUtterance(text.substring(0, 300));
                utt.lang = state.lang;
                utt.rate = 0.9;
                window.speechSynthesis.speak(utt);
            }
        }

        // ===== MAIN FUNCTIONS =====
        function updateProgress(percent) {
            state.progress = percent;
            document.querySelector('.progress-bar').style.width = `${percent}%`;
        }

        function processQuery(query) {
            const ql = query.toLowerCase();

            // Greetings
            if (/^(hi|hello|namaste|hey|namaskar)/i.test(ql)) {
                return {
                    text: "🙏 <b>Namaste!</b> How can I help you today?<br>Choose a topic tab or type your question.",
                    chips: getChips(state.topic)
                };
            }

            // ... (other query processing logic)

            // Search KB
            const allEntries = state.topic === 'all' 
                ? Object.values(KB).flat() 
                : (KB[state.topic] || []);

            let best = null, score = 0;
            for (const e of allEntries) {
                let s = 0;
                for (const k of e.kw) {
                    if (ql.includes(k)) s += k.split(' ').length;
                }
                if (s > score) {
                    score = s;
                    best = e;
                }
            }

            if (best && score > 0) {
                return { text: best.a, chips: getChips(state.topic) };
            }

            return {
                text: "🤔 <b>I couldn't find that in my knowledge base.</b><br>Try asking about rice farming, health tips, or government schemes.",
                chips: ['Rice farming', 'Fever treatment', 'PM KISAN']
            };
        }

        function sendMessage(text = null) {
            const messageText = text || state.input.trim();
            if (!messageText) return;

            state.isFirstMessage = false;
            state.input = '';
            updateUI();

            // User message
            const userMsg = {
                role: 'user',
                text: messageText,
                time: getTime()
            };

            state.messages.push(userMsg);
            state.msgCount++;
            state.totalBytes += messageText.length;
            updateProgress(30);
            updateUI();

            // Bot response
            setTimeout(() => {
                state.isTyping = true;
                updateProgress(70);
                updateUI();

                setTimeout(() => {
                    const response = processQuery(messageText);
                    const botMsg = {
                        role: 'bot',
                        text: response.text,
                        time: getTime(),
                        chips: response.chips
                    };

                    state.messages.push(botMsg);
                    state.msgCount++;
                    state.totalBytes += response.text.length;
                    state.isTyping = false;
                    updateProgress(100);
                    updateUI();

                    speak(stripTags(response.text));
                    setTimeout(() => updateProgress(0), 600);
                }, state.saverMode ? 400 : 1000);
            }, 700);
        }

        async function loadWeather() {
            if ('geolocation' in navigator) {
                try {
                    const pos = await new Promise((resolve, reject) => {
                        navigator.geolocation.getCurrentPosition(resolve, reject);
                    });
                    
                    const res = await fetch(
                        `https://api.open-meteo.com/v1/forecast?latitude=${pos.coords.latitude}&longitude=${pos.coords.longitude}` +
                        `&current=temperature_2m,relative_humidity_2m,wind_speed_10m,apparent_temperature,weather_code` +
                        `&timezone=auto`
                    );
                    const data = await res.json();
                    state.weather = {
                        temp: Math.round(data.current.temperature_2m),
                        feels: Math.round(data.current.apparent_temperature),
                        hum: data.current.relative_humidity_2m,
                        wind: Math.round(data.current.wind_speed_10m),
                        code: data.current.weather_code,
                        lat: pos.coords.latitude,
                        lon: pos.coords.longitude
                    };
                } catch (e) {
                    state.weather = null;
                }
            }
            updateUI();
        }

        function toggleMic() {
            if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
                alert('Speech recognition not supported');
                return;
            }

            if (!state.recognition) {
                const SpeechRecognition = window.webkitSpeechRecognition || window.SpeechRecognition;
                state.recognition = new SpeechRecognition();
                state.recognition.continuous = false;
                state.recognition.interimResults = false;
                state.recognition.lang = state.lang;

                state.recognition.onresult = (event) => {
                    const transcript = event.results[0][0].transcript;
                    state.input = transcript;
                    state.isListening = false;
                    sendMessage(transcript);
                    updateUI();
                };

                state.recognition.onerror = () => {
                    state.isListening = false;
                    updateUI();
                };
                
                state.recognition.onend = () => {
                    state.isListening = false;
                    updateUI();
                };
            }

            if (state.isListening) {
                state.recognition.stop();
            } else {
                state.recognition.start();
                state.isListening = true;
            }
            updateUI();
        }

        // ===== UI UPDATE FUNCTION =====
        function updateUI() {
            // Update theme
            document.body.className = state.darkMode 
                ? 'bg-gray-900 text-gray-100 min-h-screen flex flex-col'
                : 'bg-green-50 text-gray-900 min-h-screen flex flex-col';

            // Update messages
            const chatArea = document.getElementById('chat-area');
            chatArea.innerHTML = '';
            
            state.messages.forEach(msg => {
                const msgDiv = document.createElement('div');
                msgDiv.className = `flex items-end gap-2 max-w-[88%] animate-fade-in ${ 
                    msg.role === 'user' ? 'flex-row-reverse ml-auto' : 'mr-auto' 
                }`;
                
                msgDiv.innerHTML = `
                    <div class="w-9 h-9 rounded-full flex items-center justify-center text-lg flex-shrink-0 ${
                        msg.role === 'user' ? 'bg-green-500' : 'bg-gradient-to-br from-green-500 to-green-600'
                    }">
                        ${msg.role === 'user' ? '👤' : '🌾'}
                    </div>
                    <div class="rounded-2xl p-3 shadow-md max-w-full ${
                        msg.role === 'user' 
                            ? (state.darkMode ? 'bg-green-900 text-white rounded-br-md' : 'bg-green-100 text-gray-900 rounded-br-md')
                            : (state.darkMode ? 'bg-gray-800 text-white rounded-bl-md border-l-4 border-green-500' : 'bg-white text-gray-900 rounded-bl-md border-l-4 border-green-500')
                    }">
                        <div class="text-sm leading-relaxed">${msg.text}</div>
                        ${msg.chips ? `
                            <div class="flex flex-wrap gap-2 mt-3">
                                ${msg.chips.map(chip => `
                                    <button onclick="sendMessage('${chip}')" 
                                            class="px-3 py-1.5 rounded-full text-xs font-medium transition-all hover:scale-105 ${
                                                state.darkMode 
                                                    ? 'bg-green-900 text-green-300 border border-green-700 hover:bg-green-700 hover:text-white' 
                                                    : 'bg-green-50 text-green-700 border border-green-200 hover:bg-green-600 hover:text-white'
                                            }">
                                        ${chip}
                                    </button>
                                `).join('')}
                            </div>
                        ` : ''}
                        <div class="flex items-center justify-between mt-2">
                            ${msg.role === 'bot' ? `
                                <button onclick="speak('${stripTags(msg.text)}')" 
                                        class="text-xs px-2 py-1 rounded-lg font-medium transition-all ${
                                            state.darkMode 
                                                ? 'bg-gray-700 text-green-400 hover:bg-gray-600' 
                                                : 'bg-gray-100 text-green-700 hover:bg-green-100'
                                        }">
                                    🔊 Read Aloud
                                </button>
                            ` : ''}
                            <div class="text-xs text-gray-500">${msg.time}</div>
                        </div>
                    </div>
                `;
                chatArea.appendChild(msgDiv);
            });

            // Typing indicator
            if (state.isTyping) {
                const typingDiv = document.createElement('div');
                typingDiv.className = 'flex items-end gap-2 max-w-[88%] mr-auto animate-fade-in';
                typingDiv.innerHTML = `
                    <div class="w-9 h-9 rounded-full bg-gradient-to-br from-green-500 to-green-600 flex items-center justify-center text-lg">
                        🌾
                    </div>
                    <div class="${state.darkMode ? 'bg-gray-800' : 'bg-white'} rounded-2xl rounded-bl-md p-3 shadow-md"}>
                        <div class="flex gap-1.5 items-center">
                            <span class="w-2 h-2 bg-green-500 rounded-full animate-bounce"></span>
                            <span class="w-2 h-2 bg-green-500 rounded-full animate-bounce" style="animation-delay: 0.2s"></span>
                            <span class="w-2 h-2 bg-green-500 rounded-full animate-bounce" style="animation-delay: 0.4s"></span>
                        </div>
                    </div>
                `;
                chatArea.appendChild(typingDiv);
            }

            // Update input
            document.getElementById('user-input').value = state.input;

            // Scroll to bottom
            chatArea.scrollTop = chatArea.scrollHeight;
            
            // Update session timer
            const s = Math.floor((Date.now() - state.sessionStart) / 1000);
            const m = Math.floor(s / 60);
            const ss = s % 60;
            state.sessionTime = `${m}:${ss < 10 ? '0' : ''}${ss}`;
        }

        // ===== INITIAL SETUP =====
        window.onload = function() {
            // Welcome message
            setTimeout(() => {
                state.messages.push({
                    role: 'bot',
                    text: "👋 <b>Namaste! I am Gram Sahayak AI</b> 🌾<br><br>" +
                          "I am your offline-ready rural assistant. I can help you with:<br>" +
                          "🌱 Agriculture & Crops &nbsp;|&nbsp; ❤️ Health & First Aid<br>" +
                          "🌦️ Weather Advisory &nbsp;|&nbsp; 🏛️ Government Schemes<br>" +
                          "📚 Education &nbsp;|&nbsp; 🐄 Livestock &nbsp;|&nbsp; 💰 Finance &nbsp;|&nbsp; 📊 Market<br><br>" +
                          "<i>Type your question below or tap 🎙️ to speak!</i>",
                    time: getTime(),
                    chips: ['Rice farming tips', 'How to treat fever', 'PM KISAN details', 'Cow rearing guide']
                });
                state.isFirstMessage = false;
                updateUI();
            }, 500);

            // Online status
            window.addEventListener('online', () => {
                state.isOnline = true;
                updateUI();
            });
            window.addEventListener('offline', () => {
                state.isOnline = false;
                updateUI();
            });

            // Session timer
            setInterval(() => {
                const s = Math.floor((Date.now() - state.sessionStart) / 1000);
                const m = Math.floor(s / 60);
                const ss = s % 60;
                state.sessionTime = `${m}:${ss < 10 ? '0' : ''}${ss}`;
                updateUI();
            }, 1000);

            updateUI();
        };
    </script>

    <!-- Progress Bar -->
    <div class="fixed top-0 left-0 h-1 bg-green-600 progress-bar transition-all duration-300 z-50"></div>

    <!-- Main App Container -->
    <div class="flex-1 flex flex-col min-h-0">
        <!-- Header -->
        <header class="bg-gradient-to-r from-green-700 to-green-600 text-white p-3 shadow-lg sticky top-0 z-30">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                    <div class="w-11 h-11 bg-white rounded-full flex items-center justify-center text-2xl shadow-md">🌾</div>
                    <div>
                        <h1 class="text-lg font-bold">Gram Sahayak AI</h1>
                        <p class="text-xs text-green-100">Low-Bandwidth Rural Assistant</p>
                    </div>
                </div>

                <div class="flex items-center gap-2">
                    <div class="flex items-center gap-2 bg-white bg-opacity-20 px-3 py-1.5 rounded-full text-sm font-semibold">
                        <div class="w-2 h-2 rounded-full animate-pulse bg-green-300"></div>
                        <span>Online</span>
                    </div>

                    <button onclick="state.showEmergency = !state.showEmergency; updateUI()" 
                            class="w-9 h-9 rounded-full flex items-center justify-center text-lg transition-all hover:bg-white hover:bg-opacity-30">
                        🆘
                    </button>
                    <button onclick="state.showWeather = !state.showWeather; if(state.showWeather) loadWeather(); updateUI()" 
                            class="w-9 h-9 rounded-full flex items-center justify-center text-lg transition-all hover:bg-white hover:bg-opacity-30">
                        🌤️
                    </button>
                    <button onclick="state.showSettings = true; updateUI()" 
                            class="w-9 h-9 rounded-full flex items-center justify-center text-lg transition-all hover:bg-white hover:bg-opacity-30">
                        ⚙️
                    </button>
                </div>
            </div>

            <!-- Offline Banner -->
            <div class="mt-3 bg-yellow-100 text-yellow-800 px-4 py-2 rounded-lg text-sm font-medium border-l-4 border-yellow-500 hidden">
                ⚠️ You're offline — Using local knowledge base only. All core features still work!
            </div>
        </header>

        <!-- Weather Widget -->
        <div id="weather-widget" class="mx-4 mt-4 bg-gradient-to-r from-blue-700 to-blue-500 text-white p-4 rounded-2xl shadow-lg hidden">
            <!-- Weather content -->
        </div>

        <!-- Emergency Panel -->
        <div id="emergency-panel" class="mx-4 mt-4 p-4 rounded-2xl border-2 bg-red-50 border-red-200 text-red-700 hidden">
            <!-- Emergency content -->
        </div>

        <!-- Topic Tabs -->
        <div class="p-3 overflow-x-auto flex gap-2 bg-white shadow-sm dark:bg-gray-800">
            <!-- Topic buttons -->
        </div>

        <!-- Stats Bar -->
        <div class="px-4 py-2 flex gap-4 text-xs flex-wrap bg-yellow-50 text-gray-600 border-b border-yellow-100">
            <!-- Stats content -->
        </div>

        <!-- Quick Action Cards -->
        <div id="quick-actions" class="grid grid-cols-2 md:grid-cols-3 gap-3 p-4 hidden">
            <!-- Quick action buttons -->
        </div>

        <!-- Chat Area -->
        <div id="chat-area" class="flex-1 overflow-y-auto p-4 space-y-3"></div>

        <!-- Input Bar -->
        <div class="p-3 flex items-center gap-2 shadow-lg bg-white border-t border-gray-100">
            <select id="lang-select" 
                    class="px-2 py-2 rounded-lg text-sm font-medium bg-green-50 border border-green-200 text-green-700"
                    onchange="state.lang = this.value; updateUI()">
                <option value="en-IN">🇮🇳 EN</option>
                <option value="hi-IN">🇮🇳 HI</option>
                <option value="ta-IN">🇮🇳 TA</option>
                <!-- Other languages -->
            </select>

            <input id="user-input" type="text" 
                   placeholder="Ask about farming, health, weather..." 
                   class="flex-1 px-4 py-3 rounded-full text-sm outline-none transition-all border-2 border-gray-200 focus:border-green-500"
                   oninput="state.input = this.value; updateUI()"
                   onkeydown="if(event.key === 'Enter' && !event.shiftKey) { sendMessage(); event.preventDefault(); }">

            <button onclick="toggleMic()" 
                    class="w-12 h-12 rounded-full flex items-center justify-center text-xl transition-all hover:bg-green-100 bg-green-50 text-green-700">
                🎙️
            </button>

            <button onclick="sendMessage()" 
                    class="w-12 h-12 rounded-full flex items-center justify-center text-xl transition-all bg-green-600 text-white hover:bg-green-700 active:scale-95 disabled:bg-gray-300 disabled:text-gray-500 disabled:cursor-not-allowed">
                ➤
            </button>
        </div>
    </div>
</body>
</html>
