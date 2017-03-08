port module Main exposing (..)

import Time
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Kinto
import Process
import Task


-- Model


type Msg
    = NewPassphrase String
    | UpdateContent String
    | NewError String
    | GetData
    | DataRetrieved (Maybe String)
    | Lock
    | DataEncrypted String
    | DataNotEncrypted String
    | DataDecrypted (Maybe String)
    | DataNotDecrypted String
    | DataSaved String
    | BlurSelection
    | ToggleReveal
      -- Used to debounce (see debounceCount)
    | TimeOut Int
    | ToggleGearMenu


type alias Model =
    { lock : Bool
    , passphrase : String
    , content : String
    , loadedContent :
        -- may be desynchronized with "content", only used to redraw the
        -- contentEditable with some new stored/decrypted content
        String
    , modified : Bool
    , error : String
    , reveal : Bool
    , debounceCount :
        -- Debounce: each time a user input is detected, start a
        -- "Process.sleep" with a "debounceCount". Once we received the last
        -- one, we act on it.
        Int
    , encryptedData : Maybe String
    , gearMenuOpen : Bool
    }


init : ( Model, Cmd msg )
init =
    { lock = False
    , passphrase = "test"
    , content = ""
    , loadedContent = ""
    , modified = False
    , error = ""
    , reveal = False
    , debounceCount = 0
    , encryptedData = Nothing
    , gearMenuOpen = False
    }
        ! []



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        NewPassphrase passphrase ->
            { model | passphrase = passphrase } ! []

        GetData ->
            model ! [ getData {} ]

        DataRetrieved data ->
            model ! [ decryptData (Debug.log "data retrieved" { content = data, passphrase = model.passphrase }) ]

        DataDecrypted data ->
            { model
                | loadedContent = Maybe.withDefault "Edit here" (Debug.log "new data" data)
                , modified = False
                , lock = False
            }
                ! []

        DataNotDecrypted error ->
            { model | error = (Debug.log "data not decrypted" error) } ! []

        BlurSelection ->
            model ! [ blurSelection "" ]

        UpdateContent content ->
            let
                _ =
                    Debug.log "updated content" content

                debounceCount =
                    model.debounceCount + 1
            in
                { model
                    | content = content
                    , modified = True
                    , debounceCount = debounceCount
                    , lock = False
                }
                    ! [ Process.sleep Time.second |> Task.perform (always (TimeOut debounceCount)) ]

        NewError error ->
            { model | lock = True, content = "", passphrase = "", error = "Wrong passphrase" } ! []

        Lock ->
            { model | lock = True, gearMenuOpen = False, content = "", passphrase = "" } ! [ encryptData { content = model.content, passphrase = model.passphrase } ]

        DataSaved _ ->
            { model | modified = False } ! []

        ToggleReveal ->
            { model | reveal = not model.reveal } ! []

        TimeOut debounceCount ->
            if debounceCount == model.debounceCount then
                { model | debounceCount = 0 } ! [ encryptData { content = model.content, passphrase = model.passphrase } ]
            else
                model ! []

        DataEncrypted encrypted ->
            { model | encryptedData = Debug.log "encrypted data from js" <| Just encrypted } ! [ saveData encrypted ]

        DataNotEncrypted error ->
            { model | error = (Debug.log "" error) } ! []

        ToggleGearMenu ->
            { model | gearMenuOpen = not model.gearMenuOpen } ! []



-- View


formView : Model -> Html.Html Msg
formView model =
    Html.form
        [ Html.Attributes.class <|
            if model.lock then
                ""
            else
                "hidden"
        , Html.Events.onSubmit GetData
        ]
        [ Html.div [ Html.Attributes.class "spacer" ] []
        , Html.div []
            [ Html.text model.error ]
        , Html.div []
            [ Html.input
                [ Html.Attributes.id "password"
                , Html.Attributes.type_ "password"
                , Html.Attributes.placeholder "Passphrase"
                , Html.Attributes.value model.passphrase
                , Html.Events.onInput NewPassphrase
                ]
                []
            ]
        , Html.div []
            [ Html.button
                []
                [ Html.text "Unlock" ]
            ]
        , Html.div [ Html.Attributes.class "spacer" ] []
        ]


controlBar : Model -> Html.Html Msg
controlBar model =
    Html.div
        []
        [ Html.button
            [ Html.Attributes.id "sel"
            , Html.Attributes.class "btn btn-default"
            , Html.Attributes.title "Blur selection"
            , Html.Events.onClick BlurSelection
            ]
            [ Html.i [ Html.Attributes.class "glyphicon glyphicon-sunglasses" ] [] ]
        , Html.text " "
        , Html.button
            [ Html.Attributes.id "toggle-all"
            , Html.Attributes.class "btn btn-default"
            , Html.Attributes.title <|
                if model.reveal then
                    "Blur all"
                else
                    "Reveal all"
            , Html.Events.onClick ToggleReveal
            ]
            [ Html.i
                [ Html.Attributes.class <|
                    if model.reveal then
                        "glyphicon glyphicon-eye-close"
                    else
                        "glyphicon glyphicon-eye-open"
                ]
                []
            ]
        ]


padStatus : Model -> Html.Html Msg
padStatus model =
    Html.div [ Html.Attributes.class "status" ]
        [ Html.text <|
            if model.modified then
                "Modified"
            else
                "Saved"
        ]


padView : Model -> Html.Html Msg
padView model =
    Html.div
        [ Html.Attributes.class <|
            if model.lock then
                "hidden"
            else
                "pad"
        ]
        [ contentEditable model
        ]


innerHtmlDecoder =
    Decode.at [ "target", "innerHTML" ] Decode.string


contentEditable : Model -> Html.Html Msg
contentEditable model =
    Html.div
        [ Html.Attributes.class <|
            if model.reveal then
                "reveal"
            else
                ""
        , Html.Attributes.contenteditable True
        , Html.Events.on "input" (Decode.map UpdateContent innerHtmlDecoder)
        , Html.Attributes.property "innerHTML" (Encode.string model.loadedContent)
        ]
        []


gearMenu : Model -> String -> Html.Html Msg
gearMenu model icon =
    let
        divClass =
            if model.gearMenuOpen then
                "dropdown open"
            else
                "dropdown"
    in
        Html.div
            [ Html.Attributes.class divClass ]
            [ Html.button
                [ Html.Attributes.class "btn btn-default dropdown-toggle"
                , Html.Attributes.type_ "undefined"
                , Html.Attributes.id "gear-menu"
                , Html.Events.onClick ToggleGearMenu
                ]
                [ Html.i [ Html.Attributes.class "glyphicon glyphicon-cog" ] [] ]
            , Html.ul
                [ Html.Attributes.class "dropdown-menu dropdown-menu-right" ]
                [ Html.li
                    [ Html.Attributes.class "disabled" ]
                    [ Html.a [] [ Html.text "Security settings" ]
                    ]
                , Html.li
                    []
                    [ Html.a
                        [ Html.Attributes.href "#" ]
                        [ Html.i [ Html.Attributes.class "glyphicon glyphicon-ok" ] []
                        , Html.text " "
                        , Html.text "Leave unlocked"
                        ]
                    ]
                , Html.li
                    []
                    [ Html.a
                        [ Html.Attributes.href "#" ]
                        [ Html.i [ Html.Attributes.class "glyphicon glyphicon-none" ] []
                        , Html.text " "
                        , Html.text "Lock after 5 minutes"
                        ]
                    ]
                , Html.li
                    []
                    [ Html.a
                        [ Html.Attributes.id "lock"
                        , Html.Events.onClick Lock
                        ]
                        [ Html.i [ Html.Attributes.class "glyphicon glyphicon-none" ] []
                        , Html.text " "
                        , Html.text "Lock now"
                        ]
                    ]
                , Html.li
                    [ Html.Attributes.class "divider" ]
                    []
                , Html.li
                    [ Html.Attributes.class "disabled" ]
                    [ Html.a [] [ Html.text "Sync settings" ]
                    ]
                , Html.li
                    []
                    [ Html.a
                        [ Html.Attributes.id "lock"
                        , Html.Events.onClick Lock
                        ]
                        [ Html.i [ Html.Attributes.class "glyphicon glyphicon-none" ] []
                        , Html.text " "
                        , Html.text "Enable sync"
                        ]
                    ]
                ]
            ]


view : Model -> Html.Html Msg
view model =
    Html.div [ Html.Attributes.class "outer-wrapper container" ]
        [ if not model.lock then
            Html.header [ Html.Attributes.class "row" ]
                [ Html.div [ Html.Attributes.class "col-md-6" ]
                    [ controlBar model ]
                , Html.div [ Html.Attributes.class "col-md-1 col-md-offset-4" ]
                    [ padStatus model ]
                , Html.div [ Html.Attributes.class "col-md-1" ]
                    [ gearMenu model "gear" ]
                ]
          else
            Html.div [] []
        , formView model
        , padView model
        , Html.footer [] [ Html.text "Available everywhere with your Firefox Account!" ]
        ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ newData DataRetrieved
        , dataSaved DataSaved
        , newError NewError
        , dataNotEncrypted DataNotEncrypted
        , dataEncrypted DataEncrypted
        , dataDecrypted DataDecrypted
        , dataNotDecrypted DataNotDecrypted
        ]



-- Main


main =
    Html.program
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }



-- Ports
--
-- Load stored data: GetData -> DataRetrieved
-- then on user input: UpdateContent -> Debounce (via TimeOut) -> encryptData (out port) -> DataEncrypted (in port) -> saveData -> DataSaved
--
-- Get Data


port getData : {} -> Cmd msg


port newData : (Maybe String -> msg) -> Sub msg



-- Save data


port saveData : String -> Cmd msg


port dataSaved : (String -> msg) -> Sub msg



-- Decrypt data ports


port decryptData : { content : Maybe String, passphrase : String } -> Cmd msg


port dataDecrypted : (Maybe String -> msg) -> Sub msg


port dataNotDecrypted : (String -> msg) -> Sub msg


port newError : (String -> msg) -> Sub msg



-- Encrypt data ports


port encryptData : { content : String, passphrase : String } -> Cmd msg


port dataEncrypted : (String -> msg) -> Sub msg


port dataNotEncrypted : (String -> msg) -> Sub msg



-- Handle content editable features


port blurSelection : String -> Cmd msg


port copySelection : String -> Cmd msg
