port module Main exposing (..)

import Html
import Html.Attributes
import Html.Events


-- Model


type Msg
    = NewEmail String
    | NewPassphrase String
    | NewData String
    | GetData


type alias Model =
    { lock : Bool
    , email : String
    , passphrase : String
    , content : String
    }


init : ( Model, Cmd msg )
init =
    Model True "" "" "" ! []



-- Update


update : Msg -> Model -> ( Model, Cmd msg )
update message model =
    case message of
        NewEmail email ->
            { model | email = email } ! []

        NewPassphrase passphrase ->
            { model | passphrase = passphrase } ! []

        GetData ->
            model ! [ getData "hoverpad" ]

        NewData content ->
            { model | content = content, lock = False } ! []



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
    Html.div [ Html.Attributes.class "pad" ]
        [ Html.textarea []
            [ Html.text model.content ]
        ]


view : Model -> Html.Html Msg
view model =
    Html.div [ Html.Attributes.class "outer-wrapper" ]
        [ Html.h1 [] [ Html.text "Universal Notepad" ]
        , Html.a
            [ Html.Attributes.id "lock"
            , Html.Attributes.href "#"
            , Html.Attributes.class "hidden"
            ]
            [ Html.text "Lock" ]
        , router model
        , Html.span [] [ Html.text "Available everywhere with your Email and Passphrase!" ]
        ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ newData NewData ]



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


port newData : (String -> msg) -> Sub msg
