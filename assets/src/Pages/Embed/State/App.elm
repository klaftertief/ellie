module Pages.Embed.State.App exposing (..)

import Elm.Error as Error exposing (Error)
import Json.Decode as Decode exposing (Decoder)
import Pages.Embed.Effects.Handlers exposing (GetRevisionError, RunEmbedError)
import Pages.Embed.Effects.Inbound as Inbound exposing (Inbound)
import Pages.Embed.Effects.Outbound as Outbound exposing (Outbound)
import Pages.Embed.Types.EmbedUpdate as EmbedUpdate exposing (EmbedUpdate)
import Pages.Embed.Types.Panel as Panel exposing (Panel)
import Pages.Embed.Types.Revision as Revision exposing (Revision)
import Pages.Embed.Types.RevisionId as RevisionId exposing (RevisionId)
import Pages.Embed.Types.Route as Route exposing (Route)


type OutputState
    = NotRun
    | AcquiringConnection
    | Compiling
    | Finished (Maybe Error)
    | Crashed String


type alias WorkingState =
    { panel : Panel
    , revision : { id : RevisionId, data : Revision }
    , output : OutputState
    }


type Model
    = Failure
    | Loading RevisionId Panel
    | Working WorkingState


type alias Flags =
    {}


flags : Decoder Flags
flags =
    Decode.succeed {}


init : Flags -> Route -> ( Model, Outbound Msg )
init flags route =
    case route of
        Route.NotFound ->
            ( Failure, Outbound.none )

        Route.Existing revisionId panel ->
            ( Loading revisionId panel
            , Outbound.GetRevision revisionId (RevisionLoaded revisionId)
            )


type Msg
    = RevisionLoaded RevisionId (Result GetRevisionError Revision)
    | RouteChanged Route
    | UpdateReceived EmbedUpdate
    | EmbedRunStarted
    | RunCompleted (Result RunEmbedError (Maybe (Maybe Error)))
    | PanelSelected Panel


update : Msg -> Model -> ( Model, Outbound Msg )
update msg model =
    case ( model, msg ) of
        ( _, RouteChanged route ) ->
            init {} route

        ( Failure, _ ) ->
            ( model, Outbound.none )

        ( Loading rid panel, RevisionLoaded revisionId (Ok revision) ) ->
            if RevisionId.eq rid revisionId then
                ( Working { panel = panel, revision = { id = revisionId, data = revision }, output = NotRun }
                , Outbound.none
                )
            else
                ( model, Outbound.none )

        ( Loading rid panel, RevisionLoaded revisionId (Err error) ) ->
            if RevisionId.eq rid revisionId then
                ( Failure, Outbound.none )
            else
                ( model, Outbound.none )

        ( Working state, PanelSelected panel ) ->
            ( Working { state | panel = panel }
            , Outbound.none
            )

        ( Working state, EmbedRunStarted ) ->
            ( Working { state | output = AcquiringConnection }
            , Outbound.none
            )

        ( Working state, RunCompleted (Ok (Just error)) ) ->
            ( Working { state | output = Finished error }
            , Outbound.none
            )

        ( Working state, RunCompleted (Ok Nothing) ) ->
            ( Working state, Outbound.none )

        ( Working state, RunCompleted (Err _) ) ->
            ( Working { state | output = Crashed "Couldn't initiate compiler" }
            , Outbound.none
            )

        ( Working state, UpdateReceived embedUpdate ) ->
            case ( state.output, embedUpdate ) of
                ( AcquiringConnection, EmbedUpdate.Connected ) ->
                    ( Working { state | output = Compiling }
                    , Outbound.RunEmbed state.revision.id RunCompleted
                    )

                ( Compiling, EmbedUpdate.Compiled error ) ->
                    ( Working { state | output = Finished error }
                    , Outbound.none
                    )

                ( Compiling, EmbedUpdate.Failed message ) ->
                    ( Working { state | output = Crashed message }
                    , Outbound.none
                    )

                ( _, EmbedUpdate.Disconnected ) ->
                    ( Working { state | output = NotRun }
                    , Outbound.none
                    )

                _ ->
                    ( model, Outbound.none )

        _ ->
            ( model, Outbound.none )


subscriptions : Model -> Inbound Msg
subscriptions model =
    case model of
        Working state ->
            Inbound.batch
                [ case state.output of
                    AcquiringConnection ->
                        Inbound.EmbedUpdates state.revision.id UpdateReceived

                    Compiling ->
                        Inbound.EmbedUpdates state.revision.id UpdateReceived

                    _ ->
                        Inbound.none
                ]

        _ ->
            Inbound.none
