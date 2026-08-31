(function () {
    "use strict";

    function ready(callback) {
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", callback, { once: true });
            return;
        }
        callback();
    }

    function createElement(tag, className, text) {
        var element = document.createElement(tag);
        if (className) {
            element.className = className;
        }
        if (typeof text === "string") {
            element.textContent = text;
        }
        return element;
    }

    function byteSize(text) {
        if (typeof TextEncoder !== "undefined") {
            return new TextEncoder().encode(text).length;
        }
        return text.length;
    }

    function graphemes(text) {
        if (typeof Intl !== "undefined" && Intl.Segmenter) {
            var segmenter = new Intl.Segmenter("zh", { granularity: "grapheme" });
            var segments = [];
            var iterator = segmenter.segment(text)[Symbol.iterator]();
            var item = iterator.next();
            while (!item.done) {
                segments.push(item.value.segment);
                item = iterator.next();
            }
            return segments;
        }

        var units = Array.from(text);
        var merged = [];
        var marks = /[\u0300-\u036f\u1ab0-\u1aff\u1dc0-\u1dff\u20d0-\u20ff\ufe00-\ufe0f]/;
        for (var i = 0; i < units.length; i += 1) {
            var unit = units[i];
            var last = merged.length > 0 ? merged[merged.length - 1] : "";
            if (last && (marks.test(unit) || unit === "\u200d" || last.endsWith("\u200d"))) {
                merged[merged.length - 1] = last + unit;
            } else {
                merged.push(unit);
            }
        }
        return merged;
    }

    function clearTimers(timers) {
        for (var i = 0; i < timers.length; i += 1) {
            window.clearTimeout(timers[i]);
        }
        timers.length = 0;
    }

    ready(function () {
        var root = document.getElementById("markit-ai-stream-demo");
        if (!root || root.dataset.mounted === "true") {
            return;
        }

        root.dataset.mounted = "true";
        root.innerHTML = [
            '<div class="ai-demo-topbar">',
            '  <div class="ai-demo-title">',
            '    <strong>AI 对话流式渲染</strong>',
            '    <span>assistant typing -> byte chunk -> session patch</span>',
            '  </div>',
            '  <div class="ai-demo-stats" aria-live="polite">',
            '    <span class="ai-demo-chip is-live" data-ai-demo-stat="state">live</span>',
            '    <span class="ai-demo-chip" data-ai-demo-stat="chunk">chunk 0/0</span>',
            '    <span class="ai-demo-chip" data-ai-demo-stat="bytes">0 B</span>',
            '    <span class="ai-demo-chip" data-ai-demo-stat="patch">0 updates</span>',
            '  </div>',
            '</div>',
            '<div class="ai-demo-body">',
            '  <section class="ai-demo-panel" aria-label="AI chat stream">',
            '    <div class="ai-demo-panel-head"><span>AI 对话</span><code>assistant</code></div>',
            '    <div class="ai-demo-chat">',
            '      <div class="ai-demo-message is-user">',
            '        <span class="ai-demo-role">User</span>',
            '        <p>帮我生成一段 Markdown，并在回复时实时预览。</p>',
            '      </div>',
            '      <div class="ai-demo-message is-assistant">',
            '        <span class="ai-demo-role">Assistant</span>',
            '        <div class="ai-demo-answer" aria-live="polite"><span data-ai-demo-answer></span><span class="ai-demo-cursor" aria-hidden="true"></span></div>',
            '      </div>',
            '    </div>',
            '  </section>',
            '  <section class="ai-demo-panel" aria-label="Markit internals">',
            '    <div class="ai-demo-panel-head"><span>Markit 内部机制</span><code>ParseSession</code></div>',
            '    <div class="ai-demo-engine">',
            '      <div class="ai-demo-engine-grid">',
            '        <div class="ai-demo-engine-card"><span>SourceBuffer</span><strong data-ai-demo-engine="buffer">0 B</strong><small data-ai-demo-engine="buffer-note">waiting chunk</small></div>',
            '        <div class="ai-demo-engine-card"><span>UTF-8 Decoder</span><strong data-ai-demo-engine="decoder">idle</strong><small data-ai-demo-engine="decoder-note">grapheme safe</small></div>',
            '        <div class="ai-demo-engine-card"><span>Open Blocks</span><strong data-ai-demo-engine="stack">Document</strong><small data-ai-demo-engine="stack-note">no pending tail</small></div>',
            '        <div class="ai-demo-engine-card"><span>AST Delta</span><strong data-ai-demo-engine="delta">none</strong><small data-ai-demo-engine="delta-note">snapshot stable</small></div>',
            '      </div>',
            '      <div class="ai-demo-engine-stage" data-ai-demo-stage></div>',
            '    </div>',
            '    <div class="ai-demo-patch-log" data-ai-demo-log></div>',
            '  </section>',
            '</div>'
        ].join("");

        var answerText = root.querySelector("[data-ai-demo-answer]");
        var stage = root.querySelector("[data-ai-demo-stage]");
        var log = root.querySelector("[data-ai-demo-log]");
        var statChunk = root.querySelector('[data-ai-demo-stat="chunk"]');
        var statBytes = root.querySelector('[data-ai-demo-stat="bytes"]');
        var statPatch = root.querySelector('[data-ai-demo-stat="patch"]');
        var statState = root.querySelector('[data-ai-demo-stat="state"]');
        var engineBuffer = root.querySelector('[data-ai-demo-engine="buffer"]');
        var engineBufferNote = root.querySelector('[data-ai-demo-engine="buffer-note"]');
        var engineDecoder = root.querySelector('[data-ai-demo-engine="decoder"]');
        var engineDecoderNote = root.querySelector('[data-ai-demo-engine="decoder-note"]');
        var engineStack = root.querySelector('[data-ai-demo-engine="stack"]');
        var engineStackNote = root.querySelector('[data-ai-demo-engine="stack-note"]');
        var engineDelta = root.querySelector('[data-ai-demo-engine="delta"]');
        var engineDeltaNote = root.querySelector('[data-ai-demo-engine="delta-note"]');
        var timers = [];
        var answer = "";
        var totalBytes = 0;
        var updateCount = 0;
        var chunkCount = 0;
        var typingDelay = 38;
        var newlineDelay = 190;
        var punctuationDelay = 125;
        var stepHoldDelay = 1040;

        var steps = [
            {
                text: "当然可以。下面这段回复会像 AI 输出一样按 chunk 到达，Markit 会同步维护解析会话。\n\n",
                kind: "feed",
                log: "append chunk to SourceBuffer",
                stack: "Document",
                stackNote: "root frame",
                delta: "none",
                deltaNote: "waiting for block boundary",
                stage: renderSourceStage
            },
            {
                text: "它不会等整篇回答结束，而是只保留尾部状态：开放段落、块栈、引用表和插件 session state。\n\n",
                kind: "open",
                log: "ParagraphFrame pending",
                stack: "Paragraph",
                stackNote: "pending tail",
                delta: "tail",
                deltaNote: "not sealed yet",
                stage: renderPendingStage
            },
            {
                text: "Unicode 也按用户看到的字符推进：中文、Cafe\u0301、👩‍💻、emoji 与组合音标都不会被拆坏。\n\n",
                kind: "decode",
                log: "commit grapheme boundary",
                decoder: "grapheme",
                decoderNote: "Cafe\u0301 / 👩‍💻 kept together",
                stack: "Paragraph",
                stackNote: "decoder checkpoint",
                delta: "tail",
                deltaNote: "safe cursor advance",
                stage: renderUnicodeStage
            },
            {
                text: "# AI 回复摘要\n\n",
                kind: "seal",
                log: "emit HeadingNode #1",
                stack: "Document",
                stackNote: "heading sealed by newline",
                delta: "seal",
                deltaNote: "HeadingNode #1",
                stage: renderHeadingStage
            },
            {
                text: "这段话会先作为一个开放段落存在。等下一段开始时，Markit 会把它作为整段 ParagraphNode patch 提交。\n\n",
                kind: "patch",
                log: "replace pending paragraph",
                stack: "Document",
                stackNote: "paragraph finalized",
                delta: "patch",
                deltaNote: "ParagraphNode #2 whole block",
                stage: renderParagraphPatchStage
            },
            {
                text: "| 能力 | Markit 动作 |\n| --- | --- |\n| 流式输入 | feed chunk |\n| 前置节点 | patch whole block |\n\n",
                kind: "replace",
                log: "ParagraphFrame -> TableNode",
                stack: "Table",
                stackNote: "delimiter row reclassifies tail",
                delta: "replace",
                deltaNote: "pending tail -> TableNode #3",
                stage: renderTableReplaceStage
            },
            {
                text: "最终结果可以继续输出为 HTML、Markdown、Typst 或 JSON，聊天界面只需要应用这些 update。",
                kind: "ready",
                log: "final snapshot ready",
                stack: "Document",
                stackNote: "all open blocks closed",
                delta: "ready",
                deltaNote: "DocumentSnapshot",
                stage: renderReadyStage
            }
        ];

        function updateStats() {
            statChunk.textContent = "chunk " + chunkCount + "/" + steps.length;
            statBytes.textContent = totalBytes + " B";
            statPatch.textContent = updateCount + (updateCount === 1 ? " update" : " updates");
        }

        function setEngine(step) {
            engineBuffer.textContent = totalBytes + " B";
            engineBufferNote.textContent = "chunk " + chunkCount + " appended";
            engineDecoder.textContent = step.decoder || "utf-8";
            engineDecoderNote.textContent = step.decoderNote || "byte cursor advanced";
            engineStack.textContent = step.stack;
            engineStackNote.textContent = step.stackNote;
            engineDelta.textContent = step.delta;
            engineDeltaNote.textContent = step.deltaNote;
        }

        function pulse(element) {
            element.classList.remove("is-patched");
            void element.offsetWidth;
            element.classList.add("is-patched");
        }

        function writeLog(kind, text) {
            var entry = createElement("div", "ai-demo-patch-entry is-active");
            entry.appendChild(createElement("strong", "", kind));
            entry.appendChild(createElement("span", "", text));
            log.insertBefore(entry, log.firstChild);

            var entries = log.querySelectorAll(".ai-demo-patch-entry");
            for (var i = 0; i < entries.length; i += 1) {
                if (i > 3) {
                    entries[i].parentNode.removeChild(entries[i]);
                } else if (i > 0) {
                    entries[i].classList.remove("is-active");
                }
            }
        }

        function renderStage(title, body) {
            stage.innerHTML = "";
            var card = createElement("div", "ai-demo-stage-card");
            card.appendChild(createElement("span", "ai-demo-stage-kicker", title));
            body(card);
            stage.appendChild(card);
            pulse(card);
        }

        function renderSourceStage() {
            renderStage("SourceBuffer", function (card) {
                card.appendChild(createElement("strong", "", "追加 byte chunk，不复制整篇输入"));
                card.appendChild(createElement("p", "", "当前 chunk 进入 SourceBuffer，Cursor 只推进新增范围。已稳定的前置节点不会重跑。"));
            });
        }

        function renderPendingStage() {
            renderStage("Pending Tail", function (card) {
                card.appendChild(createElement("strong", "", "ParagraphFrame 保持开放"));
                card.appendChild(createElement("p", "", "段落还没有遇到块边界，只更新 tail frame；DocumentSnapshot 暂不提交这个块。"));
                card.appendChild(createElement("div", "ai-demo-internal-block is-pending", "openBlocks = [DocumentFrame, ParagraphFrame]"));
            });
        }

        function renderUnicodeStage() {
            renderStage("Unicode Decoder", function (card) {
                card.appendChild(createElement("strong", "", "按 grapheme 边界提交可见字符"));
                var row = createElement("div", "ai-demo-token-row");
                row.appendChild(createElement("span", "ai-demo-token", "中文"));
                row.appendChild(createElement("span", "ai-demo-token", "Cafe\u0301"));
                row.appendChild(createElement("span", "ai-demo-token", "👩‍💻"));
                row.appendChild(createElement("span", "ai-demo-token", "emoji"));
                card.appendChild(row);
                card.appendChild(createElement("p", "", "UTF-8 decoder 可以暂存跨 chunk 的半个码点，Cursor 不会把组合字符拆成错误 offset。"));
            });
        }

        function renderHeadingStage() {
            renderStage("Block Dispatch", function (card) {
                card.appendChild(createElement("strong", "", "# 命中 HeadingParser"));
                card.appendChild(createElement("p", "", "行结束后 HeadingNode #1 立即 sealed，同时注册 slug、编号和 toc item。"));
                card.appendChild(createElement("div", "ai-demo-internal-block", "emit: HeadingNode(start=..., end=...)"));
            });
        }

        function renderParagraphPatchStage() {
            renderStage("Whole Paragraph Patch", function (card) {
                card.appendChild(createElement("strong", "", "开放段落整段替换为稳定节点"));
                var diff = createElement("div", "ai-demo-block-diff");
                var before = createElement("div", "ai-demo-internal-block is-pending");
                before.appendChild(createElement("span", "", "before"));
                before.appendChild(createElement("p", "", "pending tail text"));
                var after = createElement("div", "ai-demo-internal-block is-done");
                after.appendChild(createElement("span", "", "after"));
                after.appendChild(createElement("p", "", "ParagraphNode #2 sealed"));
                diff.appendChild(before);
                diff.appendChild(after);
                card.appendChild(diff);
            });
        }

        function renderTableReplaceStage() {
            renderStage("Tail Reclassification", function (card) {
                card.appendChild(createElement("strong", "", "分隔行到达后，前一行不再是普通段落"));
                card.appendChild(createElement("p", "", "内部把 pending ParagraphFrame 替换成 TableFrame，并提交 TableNode #3。"));
                card.appendChild(createElement("div", "ai-demo-internal-block is-done", "replace: ParagraphNode #3 -> TableNode #3"));
            });
        }

        function renderReadyStage() {
            renderStage("Snapshot Ready", function (card) {
                card.appendChild(createElement("strong", "", "输出层只消费 IncrementalUpdate"));
                card.appendChild(createElement("p", "", "HTML、Markdown、Typst 和 JSON writer 可以继续从稳定节点输出，聊天页面只应用 delta。"));
            });
        }

        function resetDemo() {
            clearTimers(timers);
            answer = "";
            totalBytes = 0;
            updateCount = 0;
            chunkCount = 0;
            statState.textContent = "live";
            statState.classList.add("is-live");
            answerText.textContent = "";
            stage.innerHTML = "";
            log.innerHTML = "";
            updateStats();
        }

        function playStep(index) {
            if (index >= steps.length) {
                statState.textContent = "ready";
                statState.classList.remove("is-live");
                return;
            }

            var step = steps[index];
            chunkCount += 1;
            updateStats();
            typeText(step.text, function () {
                updateCount += 1;
                setEngine(step);
                step.stage();
                writeLog(step.kind, step.log);
                updateStats();
                timers.push(window.setTimeout(function () {
                    playStep(index + 1);
                }, index === 4 || index === 5 ? stepHoldDelay + 360 : stepHoldDelay));
            });
        }

        function typeText(text, done) {
            var parts = graphemes(text);
            typePart(parts, 0, done);
        }

        function typePart(parts, index, done) {
            if (index >= parts.length) {
                done();
                return;
            }

            var part = parts[index];
            answer += part;
            totalBytes = byteSize(answer);
            answerText.textContent = answer;
            engineBuffer.textContent = totalBytes + " B";
            updateStats();

            var delay = typingDelay;
            if (part === "\n") {
                delay = newlineDelay;
            } else if (part === "，" || part === "。" || part === "：" || part === "、" || part === "|" || part === "-") {
                delay = punctuationDelay;
            } else if (part === " ") {
                delay = 56;
            }

            timers.push(window.setTimeout(function () {
                typePart(parts, index + 1, done);
            }, delay));
        }

        function start() {
            resetDemo();
            timers.push(window.setTimeout(function () {
                playStep(0);
            }, 640));
        }

        start();
    });
}());
