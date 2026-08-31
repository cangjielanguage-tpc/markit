macro package commandline.macros

import std.ast.*

public macro Progress(input: Tokens): Tokens {
    return quote(progressLogger.printProgress($(input)))
}

public macro StopProgress(input: Tokens): Tokens {
    if (input.size == 0) {
        return quote(progressLogger.stopProgress())
    }

    return quote(progressLogger.stopProgress(); $(input))
}

public macro ProgressBar(input: Tokens): Tokens {
    return quote(ProgressLogger.generateProgressBar($(input)))
}

public macro Spinner(input: Tokens): Tokens {
    return quote(progressLogger.startSpinner($(input)))
}

public macro StartSpinner(input: Tokens): Tokens {
    return quote(progressLogger.startSpinner($(input)))
}

public macro UpdateSpinner(input: Tokens): Tokens {
    return quote(progressLogger.updateSpinnerMessage($(input)))
}

public macro StopSpinner(input: Tokens): Tokens {
    if (input.size == 0) {
        return quote(progressLogger.stopSpinner())
    }

    return quote(progressLogger.stopSpinner(); $(input))
}

public macro InsertBefore(input: Tokens): Tokens {
    return quote(
        if (true) {
            let __commandlineResumeMessage = progressLogger.getTransientMessage()
            let __commandlineShouldResume = progressLogger.hasActiveTransientLine()
            let __commandlineWasSpinner = progressLogger.isSpinnerRunning()
            progressLogger.dismissTransientLine()
            $(input)
            if (__commandlineShouldResume) {
                match (__commandlineResumeMessage) {
                    case Some(text) =>
                        if (__commandlineWasSpinner) {
                            progressLogger.startSpinner(text)
                        } else {
                            progressLogger.printProgress(text)
                        }
                    case None => ()
                }
            }
        }
    )
}

public macro Prompt(input: Tokens): Tokens {
    return quote(progressLogger.prompt($(input)))
}

public macro Confirm(input: Tokens): Tokens {
    return quote(progressLogger.confirm($(input)))
}

public macro Select(input: Tokens): Tokens {
    return quote(progressLogger.select($(input)))
}

public macro MultiSelect(input: Tokens): Tokens {
    return quote(progressLogger.multiSelect($(input)))
}

public macro SelectValue(input: Tokens): Tokens {
    return quote(interactiveForm.selectValue($(input)))
}

public macro MultiSelectValues(input: Tokens): Tokens {
    return quote(interactiveForm.multiSelectValues($(input)))
}

public macro RequireConfirm(input: Tokens): Tokens {
    return quote(interactiveForm.requireConfirm($(input)))
}

public macro Success(input: Tokens): Tokens {
    return quote(progressLogger.printSuccess($(input)))
}

public macro Err(input: Tokens): Tokens {
    return quote(progressLogger.printError($(input)))
}

public macro Warn(input: Tokens): Tokens {
    return quote(progressLogger.printWarning($(input)))
}

public macro Info(input: Tokens): Tokens {
    return quote(progressLogger.printInfo($(input)))
}

public macro Verbose(input: Tokens): Tokens {
    return quote(progressLogger.printInfo($(input), icon: "·", color: AnsiColor.Gray))
}

public macro Plain(input: Tokens): Tokens {
    return quote(progressLogger.log($(input)))
}

public macro NewLine(_: Tokens): Tokens {
    return quote(progressLogger.log(""))
}

public macro Write(input: Tokens): Tokens {
    return quote(print($(input), flush: true))
}

public macro PrintColored(input: Tokens): Tokens {
    return quote(progressLogger.printlnColored($(input)))
}

public macro Color(input: Tokens): Tokens {
    return quote(ColorUtil.colorize($(input)))
}

public macro Background(input: Tokens): Tokens {
    return quote(ColorUtil.colorizeBackground($(input)))
}

public macro Styled(input: Tokens): Tokens {
    return quote(ColorUtil.style($(input)))
}
