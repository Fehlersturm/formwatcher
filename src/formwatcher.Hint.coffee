
# ## The Hint decorator
#
# This decorator puts a text over a label that fades out when the user selects the label, or edits the text.



Formwatcher.Decorators.push class extends Formwatcher.Decorator

  name: "Hint"
  description: "Displays a hint in an input field."
  nodeNames: [ "INPUT", "TEXTAREA" ]
  defaultOptions:
    auto: true # This automatically makes labels into hints.
    removeTrailingColon: true # Removes the trailing ` : ` from labels.
    color: "#aaa" # The text color of the hint.

  decParseInt: (number) -> parseInt number, 10

  accepts: (input) ->
    if super input
      # If `auto` is on, and there *is* a label.
      return true  if (input.data("hint")?) or (@options.auto and Formwatcher.getLabel { input: input }, @watcher.options.automatchLabel)
    false

  decorate: (input) ->
    elements = input: input
    hint = input.data("hint")

    if !hint? or !hint
      label = Formwatcher.getLabel elements, @watcher.options.automatchLabel
      throw "The hint was empty, but there was no label."  unless label
      elements.label = label
      label.hide()
      hint = label.html()
      hint = hint.replace(/\s*\:\s*$/, "") if @options.removeTrailingColon

    Formwatcher.debug "Using hint: " + hint

    input.wrap "<span style=\"display: inline; position: relative;\" />"

    # I think this is a bit of a hack... Don't know how to get the top margin otherwise though, since `position().top` seems not to work.
    topMargin = @decParseInt input.css("marginTop")
    topMargin = 0  if isNaN(topMargin)

    leftPosition = @decParseInt(input.css("paddingLeft")) + @decParseInt(input.position().left) + @decParseInt(input.css("borderLeftWidth")) + 2 + "px" # + 2 so the cursor is not over the text

    rightPosition = @decParseInt(input.css("paddingRight")) + @decParseInt(input.position().right) + @decParseInt(input.css("borderRightWidth")) + "px"

    hintElement = $("<span />").html(hint).css(
      position: "absolute"
      display: "none"
      top: @decParseInt(input.css("paddingTop")) + @decParseInt(input.position().top) + @decParseInt(input.css("borderTopWidth")) + topMargin + "px"
      left: leftPosition
      fontSize: input.css "fontSize"
      lineHeight: input.css "lineHeight"
      fontFamily: input.css "fontFamily"
      color: @options.color
    ).addClass("hint").click(->
      input.focus()
    ).insertAfter(input)
    fadeLength = 100
    input.focus ->
      hintElement.fadeTo fadeLength, 0.4  if input.val() is ""

    input.blur ->
      hintElement.fadeTo fadeLength, 1  if input.val() is ""

    changeFunction = ->
      if input.val() is ""
        hintElement.show()
      else
        hintElement.hide()

    input.keyup changeFunction
    input.keypress ->
      _.defer changeFunction

    input.keydown ->
      _.defer changeFunction

    input.change changeFunction
    nextTimeout = 10
    # This is an ugly but very easy fix to make sure Hints are hidden when the browser autofills.
    delayChangeFunction = ->
      changeFunction()
      _.delay delayChangeFunction, nextTimeout
      nextTimeout = nextTimeout * 2
      nextTimeout = (if nextTimeout > 1000 then 1000 else nextTimeout)

    delayChangeFunction()
    elements
