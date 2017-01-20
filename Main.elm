port module Main exposing (..)

import Html


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
    Html.text "hello world"



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
--   <div class="form">
--     <div>
--       <label for="email">Email</label>
--       <input id="email" type="text" placeholder="joe.bart@team.tld"/>
--     </div>
--     <div>
--       <label for="password">Passphrase</label>
--       <input id="password" type="password" placeholder="Password" />
--     </div>
--     <div>
--       <button>Login and unlock</button>
--     </div>
--   </div>
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
