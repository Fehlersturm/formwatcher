# Formwatcher Version 2.0.0-dev
# More infos at http://www.formwatcher.org
# 
# Copyright (c) 2012, Matias Meno
# Graphics by Tjandra Mayerhold
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.



# Returns or generates a UID for any html element
$.fn.uid = ->
  id = @attr("id")
  unless id
    id = "generatedUID" + (Formwatcher.uidCounter++)
    @attr "id", id
  id


# Returns and stores attributes only for formwatcher.
# Be careful when you get data because it does return the actual object, not
# a copy of it. So if you manipulate an array, you don't have to store it again.
$.fn.fwData = (name, value) ->
  @data "_formwatcher", {}  unless @data("_formwatcher")
  return this  if name is `undefined`
  formwatcherAttributes = @data("_formwatcher")
  if value is `undefined`
    formwatcherAttributes[name]
  else
    formwatcherAttributes[name] = value
    @data "_formwatcher", formwatcherAttributes
    this


# ## Formwatcher, the global namespace
Formwatcher =
  version: "2.0.0-dev"
  debugging: false
  uidCounter: 0

  # A wrapper for console.debug that only forwards if `Formwatcher.debugging == true`
  debug: ->
    console.debug.apply console, arguments if @debugging and console?.debug?

  # Tries to find an existing errors element, and creates one if there isn't.
  getErrorsElement: (elements, createIfNotFound) ->
    input = elements.input

    errors = $("#" + input.attr("name") + "-errors") if input.attr("name")
    errors = $("#" + input.attr("id") + "-errors") unless errors?.length or !input.attr("id")

    if not errors or not errors.length
      errors = $(document.createElement("span"))
      errors.attr "id", input.attr("name") + "-errors"  if input.attr("name")
      input.after errors
    errors.hide().addClass("errors").addClass "fw-errors"
    errors

  getLabel: (elements, automatchLabel) ->
    input = elements.input
    label = undefined
    if input.attr("id")
      label = $("label[for=" + input.attr("id") + "]")
      label = `undefined`  unless label.length
    if not label and automatchLabel
      label = input.prev()
      label = `undefined`  if not label.length or label.get(0).nodeName isnt "LABEL" or label.attr("for")
    label

  changed: (elements, watcher) ->
    input = elements.input
    return  if not input.fwData("forceValidationOnChange") and (input.attr("type") is "checkbox" and input.fwData("previouslyChecked") is input.is(":checked")) or (input.fwData("previousValue") is input.val())
    input.fwData "forceValidationOnChange", false
    @setPreviousValueToCurrentValue elements
    if (input.attr("type") is "checkbox") and (input.fwData("initialyChecked") isnt input.is(":checked")) or (input.attr("type") isnt "checkbox") and (input.fwData("initialValue") isnt input.val())
      Formwatcher.setChanged elements, watcher
    else
      Formwatcher.unsetChanged elements, watcher
    watcher.validateElements elements  if watcher.options.validate

  setChanged: (elements, watcher) ->
    input = elements.input
    return  if input.fwData("changed")
    $.each elements, (index, element) ->
      element.addClass "changed"

    input.fwData "changed", true
    Formwatcher.restoreName elements  unless watcher.options.submitUnchanged
    watcher.submitForm()  if watcher.options.submitOnChange and watcher.options.ajax

  unsetChanged: (elements, watcher) ->
    input = elements.input
    return  unless input.fwData("changed")
    $.each elements, (index, element) ->
      element.removeClass "changed"

    input.fwData "changed", false
    Formwatcher.removeName elements unless watcher.options.submitUnchanged

  storeInitialValue: (elements) ->
    input = elements.input
    if input.attr("type") is "checkbox"
      input.fwData "initialyChecked", input.is(":checked")
    else
      input.fwData "initialValue", input.val()

    @setPreviousValueToInitialValue elements

  restoreInitialValue: (elements) ->
    input = elements.input
    if input.attr("type") is "checkbox"
      input.attr "checked", input.fwData("initialyChecked")
    else
      input.val input.fwData("initialValue")
    @setPreviousValueToInitialValue elements

  setPreviousValueToInitialValue: (elements) ->
    input = elements.input
    if input.attr("type") is "checkbox"
      input.fwData "previouslyChecked", input.fwData("initialyChecked")
    else
      input.fwData "previousValue", input.fwData("initialValue")

  setPreviousValueToCurrentValue: (elements) ->
    input = elements.input
    if input.attr("type") is "checkbox"
      input.fwData "previouslyChecked", input.is(":checked")
    else
      input.fwData "previousValue", input.val()

  removeName: (elements) ->
    input = elements.input
    return  if input.attr("type") is "checkbox"
    input.fwData "name", input.attr("name") or ""  unless input.fwData("name")
    input.attr "name", ""

  restoreName: (elements) ->
    input = elements.input
    return  if input.attr("type") is "checkbox"
    input.attr "name", input.fwData("name")

  Decorators: []
  decorate: (watcher, input) ->
    decorator = _.detect(watcher.decorators, (decorator) ->
      true  if decorator.accepts(input)
    )
    if decorator
      Formwatcher.debug "Decorator \"" + decorator.name + "\" found for input field \"" + input.attr("name") + "\"."
      decorator.decorate input
    else
      input: input

  Validators: []
  currentWatcherId: 0
  watchers: []
  add: (watcher) ->
    @watchers[watcher.id] = watcher

  get: (id) ->
    @watchers[id]

  getAll: ->
    @watchers

  scanDocument: ->
    handleForm = (form) ->
      form = $(form)
      return  if form.fwData("watcher")
      formId = form.attr("id")
      options = {}
      options = Formwatcher.options[formId]  if Formwatcher.options[formId]  if formId
      domOptions = form.data("fw")
      options = _.extend(options, domOptions)  if domOptions
      new Watcher(form, options)

    $("form[data-fw], form[data-fw=\"\"]").each ->
      handleForm this

    _.each Formwatcher.options, (options, formId) ->
      handleForm $("#" + formId)

  watch: (form, options) ->
    $("document").ready ->
      new Watcher(form, options)


# ## The ElementWatcher root class
# 
# This is the base class for decorators and validators.
class Formwatcher._ElementWatcher
  name: "No name"
  description: "No description"
  nodeNames: null # eg: `[ "SELECT" ]`
  classNames: [] # eg: `[ "font" ]`
  defaultOptions: { } #  Overwrite this with your default options. Those options can be overridden in the watcher config.
  options: null # On initialization this gets filled with the actual options so they don't have to be calculated every time.

  # Stores the watcher, and creates a valid options object.
  constructor: (@watcher) ->
    @options = $.extend true, {}, @defaultOptions, watcher.options[@name] ? { }

  # Overwrite this function if your logic to which elements your decorator applies
  # is more complicated than a simple nodeName/className comparison.
  accepts: (input) ->
    # If the config for a ElementWatcher is just false, it's disabled for the watcher.
    return false if @watcher.options[@name]? and @watcher.options[@name] == false
    _.any(@nodeNames, (nodeName) ->
      input.get(0).nodeName is nodeName
    ) and _.all(@classNames, (className) ->
      input.hasClass className
    )


# ## Decorator class
#
# Decorators are used to improve the visuals and user interaction of form elements.
#
# Implement it to create a new decorator.
class Formwatcher.Decorator extends Formwatcher._ElementWatcher

  # This function does all the magic.
  # It creates additional elements if necessary, and could instantiate an object
  # that will be in charge of handling this input.
  #
  # This function has to return a hash of all fields that you want to get updated
  # with .focus and .changed classes. Typically this is just { input: THE_INPUT }
  #
  # `input` has to be the actual form element to transmit the data.
  # `label` is reserved for the actual label.
  decorate: (watcher, input) ->
    input: input


# ## Validator class
#
# Instances of this class are meant to validate input fields
class Formwatcher.Validator extends Formwatcher._ElementWatcher
  # Typically most validators work on every input field
  nodeNames: [ "INPUT", "TEXTAREA", "SELECT" ]

  # Return true if the validation passed, or an error message if not.
  validate: (sanitizedValue, input) ->
    true

  # If your value can be sanitized (eg: integers should not have leading or trailing spaces)
  # this function should return the sanitized value.
  #
  # When the user leaves the input field, the value will be updated with this value in the field.
  sanitize: (value) ->
    value





# ## Default options
# Those are the default options a new watcher uses if nothing is provided.
# Overwrite any of these when instantiating a watcher (or put it in `data-fw=''`)
Formwatcher.defaultOptions =
  # Whether to convert the form to an AJAX form.
  ajax: false
  # Whether or not the form should validate on submission. This will invoke
  # every validator attached to your input fields.
  validate: true
  # If ajax and submitOnChange are true, then the form will be submitted every
  # time an input field is changed. This removes the need of a submit button.
  submitOnChange: false
  # If the form is submitted via AJAX, the formwatcher uses changed values.
  # Otherwise formwatcher removes the name parameter of the input fields so they
  # are not submitted.
  # Remember: checkboxes are ALWAYS submitted if checked, and never if unchecked.
  submitUnchanged: true
  # If you have `submitUnchanged = false` and the user did not change anything and
  # hit submit, there would not actually be anything submitted to the server.
  # To avoid that, formwatcher does not actually send the request. But if you want
  # that behaviour you can set this to true.
  submitFormIfAllUnchanged: false
  # When the form is submitted with AJAX, this tells the formwatcher how to
  # leave the form afterwards. Eg: For guestbook posts this should probably be yes.
  resetFormAfterSubmit: false
  # Creating ids for input fields, and setting the `for` attribute on the labels
  # is the right way to go, but can be a tedious task. If automatchLabel is true,
  # Formwatcher will automatically match the closest previous label without a `for`
  # attribute as the correct label.
  automatchLabel: true
  # Checks the ajax transport if everything was ok. If this function returns
  # false formwatcher assumes that the form submission resulted in an error.
  # So, if this function returns true `onSuccess` will be called. If false,
  # `onError` is called.
  responseCheck: (data) -> not data
  # This function gets called before submitting the form. You could hide the form
  # or show a spinner here.
  onSubmit: ->
  # If the responseCheck function returns true, this function gets called.
  onSuccess: (data) ->
  # If the responseCheck function returns false, this function gets called.
  onError: (data) -> alert data




# This is a map of options for your different forms. You can simply overwrite it
# to specify your form configurations, if it is too complex to be put in the
# form data-fw='' field.
#
# **CAREFUL**: When you set options here, they will be overwritten by the DOM options.
#
# Example:
#
#     Formwatcher.options.myFormId = { ajax: true };
Formwatcher.options = { }


# ## The Watcher class
#
# This is the class that gets instantiated for each form.
class Watcher
  constructor: (form, options) ->
    @form = (if typeof form is "string" then $("#" + form) else $(form))
    if @form.length < 1
      throw ("Form element not found.")
    else if @form.length > 1
      throw ("The jQuery contained more than 1 element.")
    else throw ("The element was not a form.")  if @form.get(0).nodeName isnt "FORM"
    @allElements = []
    @id = Formwatcher.currentWatcherId++
    Formwatcher.add this
    @observers = {}

    # Putting the watcher object in the form element.
    @form.fwData "watcher", this
    @form.fwData("originalAction", @form.attr("action") or "").attr "action", "javascript:undefined;"
    @options = $.extend(true, {}, Formwatcher.defaultOptions, options or {})
    @decorators = []
    @validators = []
    _.each Formwatcher.Decorators, (Decorator) =>
      @decorators.push new Decorator @

    _.each Formwatcher.Validators, (Validator) =>
      @validators.push new Validator @

    @observe "submit", @options.onSubmit
    @observe "success", @options.onSuccess
    @observe "error", @options.onError
    $.each $(":input", @form), (i, input) =>
      input = $(input)
      unless input.fwData("initialized")
        if input.attr("type") is "hidden"
          input.fwData "forceSubmission", true
        else
          elements = Formwatcher.decorate @, input
          if elements.input.get() isnt input.get()
            elements.input.attr "class", input.attr("class")
            input = elements.input
          unless elements.label
            label = Formwatcher.getLabel(elements, @options.automatchLabel)
            elements.label = label  if label
          unless elements.errors
            errorsElement = Formwatcher.getErrorsElement(elements, true)
            elements.errors = errorsElement
          @allElements.push elements
          input.fwData "validators", []
          _.each @validators, (validator) =>
            if validator.accepts input, @
              Formwatcher.debug "Validator \"" + validator.name + "\" found for input field \"" + input.attr("name") + "\"."
              input.fwData("validators").push validator

          Formwatcher.storeInitialValue elements
          if input.val() is null or not input.val()
            $.each elements, ->
              @addClass "empty"
          Formwatcher.removeName elements unless @options.submitUnchanged
          onchangeFunction = _.bind Formwatcher.changed, Formwatcher, elements, @
          validateElementsFunction = _.bind @validateElements, @, elements, true
          $.each elements, ->
            @focus _.bind(->
              @addClass "focus"
            , this)
            @blur _.bind(->
              @removeClass "focus"
            , this)
            @change onchangeFunction
            @blur onchangeFunction
            @keyup validateElementsFunction

    submitButtons = $(":submit", @form)
    hiddenSubmitButtonElement = $("<input type=\"hidden\" name=\"\" value=\"\" />")
    @form.append hiddenSubmitButtonElement
    $.each submitButtons, (i, element) =>
      element = $(element)
      element.click (e) =>
        hiddenSubmitButtonElement.attr("name", element.attr("name") or "").attr "value", element.attr("value") or ""
        @submitForm()
        e.stopPropagation()

  callObservers: (eventName) ->
    args = _.toArray(arguments)
    args.shift()
    _.each @observers[eventName], (observer) =>
      observer.apply @, args

  observe: (eventName, func) ->
    @observers[eventName] = []  if @observers[eventName] is `undefined`
    @observers[eventName].push func
    @

  stopObserving: (eventName, func) ->
    @observers[eventName] = _.select @observers[eventName], ->
      this isnt func
    @

  enableForm: -> $(":input", @form).prop "disabled", false

  disableForm: -> $(":input", @form).prop "disabled", true

  submitForm: (e) ->
    if not @options.validate or @validateForm()
      @callObservers "submit"
      if @options.ajax
        @disableForm()
        @submitAjax()
      else
        @form.attr "action", @form.fwData("originalAction")
        _.defer _.bind(->
          @form.submit()
          @disableForm()
        , this)
        false
    else

  validateForm: ->
    validated = true
    _.each @allElements, (elements) ->
      validated = false unless @validateElements(elements)
    , this
    validated

  validateElements: (elements, inlineValidating) ->
    input = elements.input
    validated = true
    if input.fwData("validators").length
      if not inlineValidating or not input.fwData("lastValidatedValue") or input.fwData("lastValidatedValue") isnt input.val()
        input.fwData "lastValidatedValue", input.val()
        Formwatcher.debug "Validating input " + input.attr("name")
        input.fwData "validationErrors", []
        validated = _.all(input.fwData("validators"), (validator) ->
          if input.val() is "" and validator.name isnt "Required"
            Formwatcher.debug "Validating " + validator.name + ". Field was empty so continuing."
            return true
          Formwatcher.debug "Validating " + validator.name
          validationOutput = validator.validate(validator.sanitize(input.val()), input)
          if validationOutput isnt true
            validated = false
            input.fwData("validationErrors").push validationOutput
            return false
          true
        )
        unless validated
          _.each elements, (element) ->
            element.removeClass "validated"

          unless inlineValidating
            elements.errors.html(input.fwData("validationErrors").join("<br />")).show()
            _.each elements, (element) ->
              element.addClass "error"
        else
          elements.errors.html("").hide()
          _.each elements, (element) ->
            element.addClass "validated"
            element.removeClass "error"

          elements.input.fwData "forceValidationOnChange", true  if inlineValidating
      if not inlineValidating and validated
        sanitizedValue = input.fwData("lastValidatedValue")
        _.each input.fwData("validators"), (validator) ->
          sanitizedValue = validator.sanitize(sanitizedValue)

        input.val sanitizedValue
    else
      _.each elements, (element) ->
        element.addClass "validated"
    validated

  submitAjax: ->
    Formwatcher.debug "Submitting form via AJAX."
    fields = {}
    i = 0

    $.each $(":input", @form), (i, input) =>
      input = $(input)
      fields[(if input.attr("name") then input.attr("name") else "unnamedInput_" + (i++))] = input.val()  if input.attr("type") isnt "checkbox" or input.is(":checked")  if input.fwData("forceSubmission") or input.attr("type") is "checkbox" or input.fwData("changed") or @options.submitUnchanged

    if _.size(fields) is 0 and not @options.submitFormIfAllUnchanged
      _.defer _.bind(->
        @enableForm()
        @ajaxSuccess()
      , this)
    else
      $.ajax
        url: @form.fwData("originalAction")
        type: "POST"
        data: fields
        context: this
        success: (data) ->
          @enableForm()
          unless @options.responseCheck(data)
            @callObservers "error", data
          else
            @callObservers "success", data
            @ajaxSuccess()
    `undefined`

  ajaxSuccess: ->
    _.each @allElements, _.bind((elements) ->
      Formwatcher.unsetChanged elements, this
      if @options.resetFormAfterSubmit
        Formwatcher.restoreInitialValue elements
      else
        Formwatcher.storeInitialValue elements
      isEmpty = (elements.input.val() is null or not elements.input.val())
      $.each elements, ->
        if isEmpty
          @addClass "empty"
        else
          @removeClass "empty"
    , this)



if window?
  window.Formwatcher = Formwatcher
  window.Watcher = Watcher

$(document).ready Formwatcher.scanDocument