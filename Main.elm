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


view : Model -> Html.Html Msg
view model =
    --   Form
    Html.div [ Html.Attributes.class "form-outer-wrapper" ]
        [ Html.div [ Html.Attributes.class "form" ]
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



-- <div class="form-outer-wrapper">
-- </div>
-- <div class="outer-wrapper hidden">
--   <h1>Universal Notepad</h1>
--   <a id="lock" href="#">Lock</a>
--   <div class="pad">
--     <textarea></textarea>
--   </div>
--   <span>Available everywhere you're signed in to Firefox</span>
--   <a id="connect" href="#">Connect a device</a>
-- </div>
