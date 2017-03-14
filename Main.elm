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


type alias Flags =
    { lockAfterSeconds : Maybe Int
    , fxaToken : Maybe String
    , contentWasSyncedRemotely : Maybe String
    , passphrase : Maybe String
    }


type Msg
    = NewError String
      -- Data encryption
    | DataEncrypted String
    | DataNotEncrypted String
      -- Data decryption
    | DataDecrypted (Maybe String)
    | DataNotDecrypted String
      -- Data retrieval and saving
    | NewPassphrase String
    | UpdateContent String
    | GetData
    | DataRetrieved (List String)
    | DataSaved String
      -- Pad tools
    | BlurSelection
    | ToggleReveal
      -- Used to debounce (see debounceCount)
    | TimeOut Int
      -- Gear menu
    | ToggleGearMenu
    | CloseGearMenu String
      -- Locking
    | Lock
    | LockTimeOut Int
    | SetLockAfterSeconds (Maybe Int)
      -- Syncing
    | EnableSyncing
    | DisableSyncing
    | FxaTokenRetrieved String
    | DataSavedInKinto (Result Kinto.Error String)
    | DataRetrievedFromKinto (Result Kinto.Error String)


type alias Model =
    { lock : Bool
    , lockAfterSeconds : Maybe Int
    , contentWasSynced : Bool
    , fxaToken : Maybe String
    , passphrase : Maybe String
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


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        contentWasSynced =
            case flags.contentWasSyncedRemotely of
                Nothing ->
                    False

                Just wasSynced ->
                    if wasSynced == "true" then
                        True
                    else
                        False

        lock =
            case flags.passphrase of
                Nothing ->
                    True

                Just _ ->
                    False

        model =
            { lock = lock
            , lockAfterSeconds = flags.lockAfterSeconds
            , fxaToken = flags.fxaToken
            , contentWasSynced = contentWasSynced
            , passphrase = flags.passphrase
            , content = ""
            , loadedContent = ""
            , modified = False
            , error = ""
            , reveal = False
            , debounceCount = 0
            , encryptedData = Nothing
            , gearMenuOpen = False
            }
    in
        lockOnStartup model flags.lockAfterSeconds



-- Update


startLockTimeOut : Maybe Int -> Int -> Cmd Msg
startLockTimeOut lockAfterSeconds debounceCount =
    case lockAfterSeconds of
        Nothing ->
            Cmd.none

        Just lockAfterSeconds ->
            if lockAfterSeconds /= 0 then
                Process.sleep (Time.second * (toFloat lockAfterSeconds))
                    |> Task.perform (always (LockTimeOut debounceCount))
            else
                Cmd.none


lockOnStartup : Model -> Maybe Int -> ( Model, Cmd Msg )
lockOnStartup model lockAfterSeconds =
    if model.lock then
        model ! []
    else
        case lockAfterSeconds of
            Nothing ->
                model ! [ getData {}, retrieveData model.fxaToken ]

            Just seconds ->
                if seconds == 0 then
                    update Lock model
                else
                    model ! [ getData {}, retrieveData model.fxaToken ]


encryptIfPassphrase : Maybe String -> String -> Cmd Msg
encryptIfPassphrase passphrase content =
    case passphrase of
        Nothing ->
            Cmd.none

        Just passphrase ->
            encryptData { content = content, passphrase = passphrase }


decryptIfPassphrase : Maybe String -> Maybe String -> Cmd Msg
decryptIfPassphrase passphrase content =
    case passphrase of
        Nothing ->
            Cmd.none

        Just passphrase ->
            decryptData { content = content, passphrase = passphrase }


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        NewPassphrase passphrase ->
            { model
                | passphrase =
                    if passphrase == "" then
                        Nothing
                    else
                        Just passphrase
            }
                ! []

        GetData ->
            { model | error = "" } ! [ savePassphrase model.passphrase, getData {}, retrieveData model.fxaToken ]

        DataRetrieved list ->
            case list of
                [ "pad", data ] ->
                    case model.passphrase of
                        Nothing ->
                            { model | error = "No passphrase to decrypt content." } ! []

                        Just passphrase ->
                            model ! [ decryptIfPassphrase model.passphrase (Just data) ]

                [ key, value ] ->
                    Debug.crash ("Unsupported newData key: " ++ key)

                _ ->
                    Debug.crash "Should never retrieve empty params."

        DataDecrypted data ->
            let
                content =
                    if model.loadedContent == "" || model.loadedContent == "Edit here" || model.contentWasSynced then
                        Maybe.withDefault "Edit here" (Debug.log "new data" data)
                    else if model.loadedContent == Maybe.withDefault "" (Debug.log "new data" data) then
                        model.loadedContent
                    else
                        model.loadedContent ++ "<br/> ==== <br/>" ++ Maybe.withDefault "" (Debug.log "new data" data)
            in
                { model
                    | loadedContent = content
                    , modified = False
                    , lock = False
                }
                    ! [ startLockTimeOut model.lockAfterSeconds model.debounceCount ]

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
                    ! [ Process.sleep Time.second |> Task.perform (always (TimeOut debounceCount))
                      , startLockTimeOut model.lockAfterSeconds debounceCount
                      ]

        NewError error ->
            { model | lock = True, content = "", passphrase = Nothing, error = "Wrong passphrase" } ! []

        Lock ->
            { model | lock = True, gearMenuOpen = False, content = "", passphrase = Nothing } ! [ dropPassphrase {}, encryptIfPassphrase model.passphrase model.content ]

        DataSaved key ->
            case key of
                "pad" ->
                    { model | modified = False } ! []

                "contentWasSynced" ->
                    { model | contentWasSynced = True } ! []

                _ ->
                    model ! []

        ToggleReveal ->
            { model | reveal = not model.reveal } ! []

        TimeOut debounceCount ->
            if debounceCount == model.debounceCount then
                model ! [ encryptIfPassphrase model.passphrase model.content ]
            else
                model ! []

        LockTimeOut debounceCount ->
            if debounceCount == model.debounceCount then
                update Lock model
            else
                model ! []

        DataEncrypted encrypted ->
            { model | encryptedData = Debug.log "encrypted data from js" <| Just encrypted } ! [ saveData { key = "pad", content = Encode.string encrypted }, uploadData model.fxaToken encrypted ]

        DataNotEncrypted error ->
            { model | error = (Debug.log "" error) } ! []

        ToggleGearMenu ->
            { model | gearMenuOpen = not model.gearMenuOpen } ! []

        CloseGearMenu _ ->
            { model | gearMenuOpen = False } ! []

        SetLockAfterSeconds lockAfterSeconds ->
            { model | lockAfterSeconds = lockAfterSeconds }
                ! [ saveData
                        { key = "lockAfterSeconds"
                        , content =
                            case lockAfterSeconds of
                                Just val ->
                                    Encode.int val

                                Nothing ->
                                    Encode.null
                        }
                  ]

        EnableSyncing ->
            model ! [ enableSync {} ]

        DisableSyncing ->
            { model | fxaToken = Nothing } ! [ saveData { key = "bearer", content = Encode.null } ]

        FxaTokenRetrieved token ->
            { model | fxaToken = Just token } ! [ retrieveData (Just token) ]

        DataSavedInKinto result ->
            let
                _ =
                    Debug.log "kinto result" result
            in
                model ! [ saveData { key = "contentWasSynced", content = Encode.string "true" } ]

        DataRetrievedFromKinto (Ok data) ->
            model ! [ decryptIfPassphrase model.passphrase (Just data) ]

        DataRetrievedFromKinto (Err (Kinto.ServerError 404 _ error)) ->
            update (UpdateContent model.loadedContent) model

        DataRetrievedFromKinto (Err error) ->
            { model | error = (Debug.log "data not retrieved" (toString error)) } ! []



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


uploadData : Maybe String -> String -> Cmd Msg
uploadData fxaToken content =
    case fxaToken of
        Nothing ->
            Cmd.none

        Just token ->
            let
                data =
                    encodeContent content

                client =
                    Kinto.client kintoServer (Kinto.Bearer token)
            in
                client
                    |> Kinto.replace recordResource "hoverpad-content" data
                    |> Kinto.send DataSavedInKinto


retrieveData : Maybe String -> Cmd Msg
retrieveData fxaToken =
    case fxaToken of
        Nothing ->
            (Debug.log "Nothing" Cmd.none)

        Just token ->
            let
                client =
                    Kinto.client kintoServer (Kinto.Bearer token)
            in
                (Debug.log "Something" client
                    |> Kinto.get recordResource "hoverpad-content"
                    |> Kinto.send DataRetrievedFromKinto
                )



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
                , Html.Attributes.value (Maybe.withDefault "" model.passphrase)
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


lockMenuEntry : Model -> String -> Maybe Int -> Html.Html Msg
lockMenuEntry model title lockAfterSeconds =
    let
        iconClass =
            if model.lockAfterSeconds == lockAfterSeconds then
                "glyphicon glyphicon-ok"
            else
                "glyphicon glyphicon-none"
    in
        Html.li
            []
            [ Html.a
                [ Html.Attributes.href "#"
                , Html.Events.onClick (SetLockAfterSeconds lockAfterSeconds)
                ]
                [ Html.i [ Html.Attributes.class iconClass ] []
                , Html.text " "
                , Html.text title
                ]
            ]


syncMenuEntry : Model -> Html.Html Msg
syncMenuEntry model =
    let
        ( label, eventName ) =
            case model.fxaToken of
                Nothing ->
                    ( "Enable sync", EnableSyncing )

                Just fxaToken ->
                    ( "Disable sync", DisableSyncing )
    in
        Html.li []
            [ Html.a
                [ Html.Attributes.href "#"
                , Html.Events.onClick eventName
                ]
                [ Html.i [ Html.Attributes.class "glyphicon glyphicon-none" ] []
                , Html.text " "
                , Html.text label
                ]
            ]


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
                , onClickStopPropagation ToggleGearMenu
                ]
                [ Html.i [ Html.Attributes.class "glyphicon glyphicon-cog" ] [] ]
            , Html.ul
                [ Html.Attributes.class "dropdown-menu dropdown-menu-right" ]
                [ Html.li
                    [ Html.Attributes.class "disabled" ]
                    [ Html.a [] [ Html.text "Security settings" ]
                    ]
                , lockMenuEntry model "Leave unlocked" Nothing
                , lockMenuEntry model "Lock after 10 seconds" <| Just 10
                , lockMenuEntry model "Lock after 5 minutes" <| Just 300
                , lockMenuEntry model "Lock after 10 minutes" <| Just 600
                , lockMenuEntry model "Lock after 1 hour" <| Just 3600
                , lockMenuEntry model "Lock on restart" <| Just 0
                , Html.li
                    []
                    [ Html.a
                        [ Html.Attributes.id "lock"
                        , Html.Attributes.href "#"
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
                    [ Html.a [] [ Html.text "Sync settings" ] ]
                , syncMenuEntry model
                ]
            ]


onClickStopPropagation : msg -> Html.Attribute msg
onClickStopPropagation message =
    Html.Events.onWithOptions "click" { stopPropagation = True, preventDefault = False } (Decode.succeed message)


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
        , bodyClicked CloseGearMenu
        , syncEnabled FxaTokenRetrieved
        ]



-- Main


main =
    Html.programWithFlags
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
-- CloseGearMenu from Javascript


port bodyClicked : (String -> msg) -> Sub msg



-- Get Data


port getData : {} -> Cmd msg


port newData : (List String -> msg) -> Sub msg



-- Save data


port saveData : { key : String, content : Encode.Value } -> Cmd msg


port dataSaved : (String -> msg) -> Sub msg


port savePassphrase : Maybe String -> Cmd msg


port dropPassphrase : {} -> Cmd msg



-- Decrypt data ports


port decryptData : { content : Maybe String, passphrase : String } -> Cmd msg


port dataDecrypted : (Maybe String -> msg) -> Sub msg


port dataNotDecrypted : (String -> msg) -> Sub msg


port newError : (String -> msg) -> Sub msg



-- Encrypt data ports


port encryptData : { content : String, passphrase : String } -> Cmd msg


port dataEncrypted : (String -> msg) -> Sub msg


port dataNotEncrypted : (String -> msg) -> Sub msg



-- Firefox Account Flow


port enableSync : {} -> Cmd msg


port syncEnabled : (String -> msg) -> Sub msg



-- Handle content editable features


port blurSelection : String -> Cmd msg


port copySelection : String -> Cmd msg
