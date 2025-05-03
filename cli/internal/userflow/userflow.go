package userflow

import (
	"fmt"

	"github.com/AlecAivazis/survey/v2"
)

func AskToProceedOrAuto(message string, nonInteractive bool) bool {
	if nonInteractive {
		fmt.Printf("[non-interactive] %s -> auto-confirmed.\n", message)
		return true
	}
	return AskToProceed(message)
}

func AskToProceed(msg string) bool {
	var proceed bool
	err := survey.AskOne(&survey.Confirm{Message: msg, Default: true}, &proceed)
	if err != nil {
		fmt.Println("Aborted or failed:", err)
		return false
	}
	return proceed
}
