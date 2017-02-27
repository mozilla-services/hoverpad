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


kintoServer =
    "https://kinto.dev.mozaws.net/v1/"



-- Model


type
    Msg
    -- Load stored data: GetData -> DataRetrieved
    -- then on user input: UpdateContent -> Debounce (via TimeOut) -> encryptData (out port) -> DataEncrypted (in port) -> saveData -> DataSaved
    = NewEmail String
    | NewPassphrase String
    | UpdateContent String
    | NewError String
    | GetData
    | DataRetrieved (Result Kinto.Error String)
    | Lock
    | DataEncrypted String
    | DataNotEncrypted String
    | DataDecrypted (Maybe String)
    | DataNotDecrypted String
    | DataSaved (Result Kinto.Error String)
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
    , encryptedData : Maybe String
    }


init : ( Model, Cmd msg )
init =
    Model True "" "" "" "" False "" False 0 Nothing ! []



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        NewEmail email ->
            { model | email = email } ! []

        NewPassphrase passphrase ->
            { model | passphrase = passphrase } ! []

        GetData ->
            { model | error = "" } ! [ getData model.email model.passphrase ]

        DataRetrieved (Ok data) ->
            model ! [ decryptData (Debug.log "data retrieved" { content = data, passphrase = model.passphrase }) ]

        DataRetrieved (Err (Kinto.ServerError 404 _ error)) ->
            { model
                | loadedContent = "new data"
                , modified = False
                , lock = False
            }
                ! []

        DataRetrieved (Err error) ->
            { model | error = (Debug.log "data not retrieved" (toString error)) } ! []

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

        CopySelection ->
            model ! [ copySelection "" ]

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
            { model | lock = True, content = "", passphrase = "" } ! [ encryptData { content = model.content, passphrase = model.passphrase } ]

        DataSaved result ->
            let
                _ =
                    Debug.log "kinto result" result
            in
                { model | modified = False } ! []

        ToggleReveal ->
            { model | reveal = not model.reveal } ! []

        TimeOut debounceCount ->
            if debounceCount == model.debounceCount then
                { model | debounceCount = 0 } ! [ encryptData { content = model.content, passphrase = model.passphrase } ]
            else
                model ! []

        DataEncrypted encrypted ->
            { model | encryptedData = Debug.log "encrypted data from js" <| Just encrypted } ! [ saveData model.email model.passphrase encrypted ]

        DataNotEncrypted error ->
            { model | error = (Debug.log "" error) } ! []



-- Kinto related


recordResource : Kinto.Resource String
recordResource =
    Kinto.recordResource
        "default"
        "hoverpad"
        (Decode.field "content" Decode.string)


decodeContent : Decode.Decoder String
decodeContent =
    (Decode.field "content" Decode.string)


encodeContent : String -> Encode.Value
encodeContent content =
    Encode.object [ ( "content", Encode.string content ) ]


saveData : String -> String -> String -> Cmd Msg
saveData email passphrase content =
    let
        data =
            encodeContent content

        client =
            Kinto.client kintoServer (Kinto.Basic email passphrase)
    in
        client
            |> Kinto.replace recordResource "hoverpad-content" data
            |> Kinto.send DataSaved


getData : String -> String -> Cmd Msg
getData email passphrase =
    let
        client =
            Kinto.client kintoServer (Kinto.Basic email passphrase)
    in
        client
            |> Kinto.get recordResource "hoverpad-content"
            |> Kinto.send DataRetrieved



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
        [ newError NewError
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


port decryptData : { content : String, passphrase : String } -> Cmd msg


port dataDecrypted : (Maybe String -> msg) -> Sub msg


port dataNotDecrypted : (String -> msg) -> Sub msg


port newError : (String -> msg) -> Sub msg


port encryptData : { content : String, passphrase : String } -> Cmd msg


port dataEncrypted : (String -> msg) -> Sub msg


port dataNotEncrypted : (String -> msg) -> Sub msg


port blurSelection : String -> Cmd msg


port copySelection : String -> Cmd msg
