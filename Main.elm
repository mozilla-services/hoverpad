port module Main exposing (..)

import Html
import Html.Attributes


-- Model


type Msg
    = Noop


type alias Model =
    { content : String }


init : ( Model, Cmd msg )
init =
    Model "" ! []



-- Update


update : Msg -> Model -> ( Model, Cmd msg )
update message model =
    case message of
        Noop ->
            model ! []



-- View


formView : Model -> Html.Html Msg
formView model =
    Html.div [ Html.Attributes.class "form" ]
        [ Html.div []
            [ Html.label [ Html.Attributes.for "email" ] [ Html.text "Email" ]
            , Html.input
                [ Html.Attributes.id "email"
                , Html.Attributes.type_ "text"
                , Html.Attributes.placeholder "joe.bart@team.tld"
                ]
                []
            ]
        , Html.div []
            [ Html.label [ Html.Attributes.for "password" ] [ Html.text "Passphrase" ]
            , Html.input
                [ Html.Attributes.id "password"
                , Html.Attributes.type_ "password"
                , Html.Attributes.placeholder "Passphrase"
                ]
                []
            ]
        , Html.div []
            [ Html.button [] [ Html.text "Login and unlock" ]
            ]
        ]


padView : Model -> Html.Html Msg
padView model =
    Html.div [ Html.Attributes.class "pad" ] [ Html.textarea [] [] ]


view : Model -> Html.Html Msg
view model =
    -- If model.lock → Display the form
    -- Else → Display the unencrypted pad
    Html.div [ Html.Attributes.class "outer-wrapper" ]
        [ Html.h1 [] [ Html.text "Universal Notepad" ]
        , Html.a
            [ Html.Attributes.id "lock"
            , Html.Attributes.href "#"
            , Html.Attributes.class "hidden"
            ]
            [ Html.text "Lock" ]
        , formView model
        , Html.span [] [ Html.text "Available everywhere with your Email and Passphrase!" ]
        ]



-- Subscriptions


subscriptions : Model -> Sub msg
subscriptions model =
    Sub.none



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
