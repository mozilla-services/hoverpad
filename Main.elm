port module Main exposing (..)

import Time
import Html
import Html.Attributes
import Html.Events
import Json.Decode
import Json.Encode
import Process
import Task


-- Model


type
    Msg
    -- Load stored data: GetData -> NewData
    -- then on user input: UpdateContent -> Debounce (via TimeOut) -> setData -> DataSaved
    = NewEmail String
    | NewPassphrase String
    | NewData (Maybe String)
    | UpdateContent String
    | NewError String
    | GetData
    | Lock
    | DataSaved String
    | DataNotSaved String
    | BlurSelection
    | CopySelection
    | ToggleReveal
      -- Used to debounce (see debounceCount)
    | TimeOut Int


type alias Model =
    { lock : Bool
    , email : String
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
    }


init : ( Model, Cmd msg )
init =
    Model True "" "" "" "" False "" False 0 ! []



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        NewEmail email ->
            { model | email = email } ! []

        NewPassphrase passphrase ->
            { model | passphrase = passphrase } ! []

        GetData ->
            { model | error = "" } ! [ getData { email = model.email, passphrase = model.passphrase } ]

        BlurSelection ->
            model ! [ blurSelection "" ]

        CopySelection ->
            model ! [ copySelection "" ]

        NewData data ->
            { model
                | loadedContent = Maybe.withDefault "Edit here" (Debug.log "new data" data)
                , modified = False
                , lock = False
            }
                ! []

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
            { model | lock = True, content = "", passphrase = "" } ! [ setData model.content ]

        DataSaved _ ->
            { model | modified = False } ! []

        DataNotSaved error ->
            { model | error = (Debug.log "" error) } ! []

        ToggleReveal ->
            { model | reveal = not model.reveal } ! []

        TimeOut debounceCount ->
            if debounceCount == model.debounceCount then
                { model | debounceCount = 0 } ! [ setData model.content ]
            else
                model ! []



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
            [ Html.label [ Html.Attributes.for "email" ] [ Html.text "Email" ]
            , Html.input
                [ Html.Attributes.id "email"
                , Html.Attributes.type_ "text"
                , Html.Attributes.placeholder "joe.bart@team.tld"
                , Html.Attributes.value model.email
                , Html.Events.onInput NewEmail
                ]
                []
            ]
        , Html.div []
            [ Html.label [ Html.Attributes.for "password" ] [ Html.text "Passphrase" ]
            , Html.input
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
                [ Html.text "Login and unlock" ]
            ]
        , Html.div [ Html.Attributes.class "spacer" ] []
        ]


controlBar : Model -> Html.Html Msg
controlBar model =
    Html.div
        [ Html.Attributes.class "control-bar"
        ]
        [ Html.button
            [ Html.Attributes.id "sel"
            , Html.Events.onClick BlurSelection
            ]
            [ Html.text "Blur selection" ]
        , Html.button
            [ Html.Attributes.id "toggle-all"
            , Html.Events.onClick ToggleReveal
            ]
            [ Html.text <|
                if model.reveal then
                    "Blur all"
                else
                    "Reveal all"
            ]
        , Html.button
            [ Html.Attributes.id "copy"
            , Html.Events.onClick CopySelection
            ]
            [ Html.text "Copy selection"
            ]
        , Html.p
            []
            [ Html.text <|
                if model.modified then
                    "Modified"
                else
                    "Saved"
            ]
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
        [ controlBar model
        , contentEditable model
        ]


innerHtmlDecoder =
    Json.Decode.at [ "target", "innerHTML" ] Json.Decode.string


contentEditable : Model -> Html.Html Msg
contentEditable model =
    Html.div
        [ Html.Attributes.class <|
            if model.reveal then
                "reveal"
            else
                ""
        , Html.Attributes.contenteditable True
        , Html.Events.on "input" (Json.Decode.map UpdateContent innerHtmlDecoder)
        , Html.Attributes.property "innerHTML" (Json.Encode.string model.loadedContent)
        ]
        []


view : Model -> Html.Html Msg
view model =
    let
        title =
            case model.lock of
                True ->
                    "Universal Notepad"

                False ->
                    model.email
    in
        Html.div [ Html.Attributes.class "outer-wrapper" ]
            [ Html.header []
                [ Html.h1 [] [ Html.text title ]
                , Html.a
                    [ Html.Attributes.id "lock"
                    , Html.Attributes.href "#"
                    , Html.Attributes.class <|
                        if model.lock then
                            "hidden"
                        else
                            ""
                    , Html.Events.onClick Lock
                    ]
                    [ Html.text "Lock" ]
                ]
            , formView model
            , padView model
            , Html.footer [] [ Html.text "Available everywhere with your Email and Passphrase!" ]
            ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ newData NewData
        , newError NewError
        , dataSaved DataSaved
        , dataNotSaved DataNotSaved
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


port getData : { email : String, passphrase : String } -> Cmd msg


port newData : (Maybe String -> msg) -> Sub msg


port newError : (String -> msg) -> Sub msg


port setData : String -> Cmd msg


port dataSaved : (String -> msg) -> Sub msg


port dataNotSaved : (String -> msg) -> Sub msg


port blurSelection : String -> Cmd msg


port copySelection : String -> Cmd msg
