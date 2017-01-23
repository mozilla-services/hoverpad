port module Main exposing (..)

import Time
import Html
import Html.Attributes
import Html.Events


-- Model


type Msg
    = NewEmail String
    | NewPassphrase String
    | NewData (List String)
    | GetData
    | Lock
    | SetData String
    | DataSaved String
    | UnBlink Time.Time


type alias Model =
    { lock : Bool
    , email : String
    , passphrase : String
    , content : String
    , blink : Bool
    , error : String
    }


init : ( Model, Cmd msg )
init =
    Model True "" "" "" False "" ! []



-- Update


update : Msg -> Model -> ( Model, Cmd msg )
update message model =
    case message of
        UnBlink time ->
            { model | blink = False } ! []

        NewEmail email ->
            { model | email = email } ! []

        NewPassphrase passphrase ->
            { model | passphrase = passphrase } ! []

        GetData ->
            { model | error = "" } ! [ getData (model.email ++ "," ++ model.passphrase) ]

        NewData results ->
            case (List.head results) of
                Just status ->
                    case status of
                        "ok" ->
                            case (List.head (List.reverse results)) of
                                Just content ->
                                    { model | content = content, lock = False } ! []

                                Nothing ->
                                    model ! []

                        _ ->
                            { model | passphrase = "", lock = True, error = "Wrong passphrase" } ! []

                Nothing ->
                    model ! []

        Lock ->
            { model | lock = True, content = "", passphrase = "" } ! []

        SetData content ->
            { model | content = content } ! [ setData content ]

        DataSaved status ->
            case status of
                "ok" ->
                    { model | blink = True } ! []

                _ ->
                    model ! []



-- View


router : Model -> Html.Html Msg
router model =
    -- If model.lock → Display the form
    -- Else → Display the unencrypted pad
    case model.lock of
        True ->
            formView model

        False ->
            padView model


formView : Model -> Html.Html Msg
formView model =
    Html.div [ Html.Attributes.class "form" ]
        [ Html.div []
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
                [ Html.Events.onClick GetData ]
                [ Html.text "Login and unlock" ]
            ]
        ]


padView : Model -> Html.Html Msg
padView model =
    let
        blinkClass =
            case model.blink of
                True ->
                    "blink"

                False ->
                    ""
    in
        Html.div [ Html.Attributes.class "pad" ]
            [ Html.textarea
                [ Html.Attributes.class blinkClass
                , Html.Events.onInput SetData
                ]
                [ Html.text model.content ]
            ]


view : Model -> Html.Html Msg
view model =
    let
        lockClass =
            case model.lock of
                True ->
                    "hidden"

                False ->
                    ""
    in
        Html.div [ Html.Attributes.class "outer-wrapper" ]
            [ Html.h1 [] [ Html.text "Universal Notepad" ]
            , Html.a
                [ Html.Attributes.id "lock"
                , Html.Attributes.href "#"
                , Html.Attributes.class lockClass
                , Html.Events.onClick Lock
                ]
                [ Html.text "Lock" ]
            , router model
            , Html.span [] [ Html.text "Available everywhere with your Email and Passphrase!" ]
            ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ newData NewData
        , dataSaved DataSaved
        , Time.every (Time.millisecond * 200) UnBlink
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


port getData : String -> Cmd msg


port newData : (List String -> msg) -> Sub msg


port setData : String -> Cmd msg


port dataSaved : (String -> msg) -> Sub msg
