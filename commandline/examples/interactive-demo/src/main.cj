package commandline_interactive_demo

import commandline.macros.{Confirm, MultiSelect, MultiSelectValues, Plain, Prompt, RequireConfirm, Select, SelectValue, Success}
import commandline.terminal.{MultiSelectResult, SelectResult, interactiveForm, progressLogger}

main(): Int {
    @Plain("Interactive commandline demo")
    @Plain("Try backspace in Prompt, arrow keys in Select/MultiSelect, and direct y/n in Confirm.")

    let projectName = @Prompt("Project name", defaultValue: Some("demo-app"))
    let accessToken = @Prompt("Access token", secret: true)
    let templateValue = @SelectValue("Template", ["basic", "docs", "website"], defaultIndex: Some(0))
    let featureValues = @MultiSelectValues(
        "Features",
        ["spinner", "color", "interactive", "password-prompt"],
        defaultIndices: [0, 1]
    )
    let templateIndex = @Select("Template index view", ["basic", "docs", "website"], defaultIndex: Some(0))
    let featureIndexes = @MultiSelect(
        "Feature index view",
        ["spinner", "color", "interactive", "password-prompt"],
        defaultIndices: [0, 1]
    )
    let shouldGenerate = @Confirm("Generate project?", defaultValue: Some(true))

    @Plain("")
    @Plain("Collected values")
    @Plain("project=${projectName}")
    @Plain("token.length=${accessToken.toRuneArray().size}")
    match (templateValue) {
        case Some(value) => @Plain("template.value=${value}")
        case None => @Plain("template.value=cancelled")
    }
    match (featureValues) {
        case Some(values) => @Plain("features.value=${values}")
        case None => @Plain("features.value=cancelled")
    }
    match (templateIndex) {
        case SelectResult.Selected(index) => @Plain("template.index=${index}")
        case SelectResult.Cancelled => @Plain("template.index=cancelled")
    }
    match (featureIndexes) {
        case MultiSelectResult.Selected(indices) => @Plain("features.index=${indices}")
        case MultiSelectResult.Cancelled => @Plain("features.index=cancelled")
    }
    @Plain("confirm=${shouldGenerate}")

    if (shouldGenerate) {
        @RequireConfirm("Final confirmation", defaultValue: Some(true), abortMessage: "final confirmation declined")
        @Success("Project confirmed")
    } else {
        @Plain("Confirmation declined")
    }

    let formTemplate = interactiveForm.selectValue("Form API template", ["basic", "docs", "website"], defaultIndex: Some(1))
    match (formTemplate) {
        case Some(value) => @Plain("form.template=${value}")
        case None => @Plain("form.template=cancelled")
    }

    return 0
}
