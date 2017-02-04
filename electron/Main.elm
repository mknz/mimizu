port module Main exposing (..)

import Electron.IpcRenderer as IPC exposing (on, send)

import Html exposing (Html, program, text, button, h1, h2, div, input, a, span, p, header, iframe, nav)
import Html.Attributes exposing (class, id, type_, placeholder, value, href, style, src, title)
import Html.Events exposing (onClick, onInput)
import Json.Encode
import Json.Decode exposing (int, string, float, bool, nullable, map, map3, map2, map4, field, at, list, Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)
import Json.Encode
import Http
import Markdown


main =
  program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

type alias Model =
  { currentQuery: String,
    numResultPage: Int,
    pagelen: Int,
    searchResult: SearchResult,
    serverMessage: String
  }

type alias SearchResult =
  { rows: List SearchResultRow,
    nHits: Int
  }

type alias SearchResultRow =
  { title: String,
    fileName: String,
    numPage: Int,
    body: String
  }


-- JSON decoders

rowDecoder =
  map4 SearchResultRow (field "title" string) (field "document_file_name" string) (field "page" int) (field "highlighted_body" string)

searchResponseDecoder : Decoder SearchResult
searchResponseDecoder =
  map2 SearchResult (at ["results"] <| list rowDecoder) (at ["n_hits"] <| int)


-- Init

init : ( Model, Cmd Msg )
init =
  ({ currentQuery = "", numResultPage = 1, pagelen = 10, searchResult = { rows = [], nHits = 0 }, serverMessage = "" }, Cmd.none)


-- UPDATE

type Msg
  = SendSearch String
  | NewSearchResult (Result Http.Error SearchResult)
  | GetNextResultPage
  | OpenDocument (String, Int)
  | AddFilesToDB

port openNewFile : (String, Int) -> Cmd msg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    SendSearch query ->
      ( { model | currentQuery = query }, search query model.numResultPage model.pagelen)
    NewSearchResult (Ok res) ->
      ( { model | searchResult = res }, Cmd.none )
    NewSearchResult (Err _) ->
      ( { model | numResultPage = 1, searchResult = { rows = [], nHits = 0 } }, Cmd.none )
    GetNextResultPage ->
    -- pagenation
      let
        totalPage =  model.searchResult.nHits // model.pagelen + 1
      in
        if model.numResultPage < totalPage then
          ( { model | numResultPage = model.numResultPage + 1 }, search model.currentQuery model.numResultPage model.pagelen)
        else  -- last page
          ( model , Cmd.none )

    OpenDocument (fileName, numPage) ->
      ( model, openNewFile (fileName, numPage) )
    AddFilesToDB ->
    -- send request to electron main process
      ( model, IPC.send "pdf-extract-request-main" Json.Encode.null)

-- VIEW

view : Model -> Html Msg
view model =
  let
      createComponent row =
        let
          sBody = row.title ++ " (p" ++ toString row.numPage ++  "): " ++ row.body
        in
          div [] [ div [ class "search-result", onClick (OpenDocument (row.fileName, row.numPage)) ] [ Markdown.toHtml [] sBody ]
          ]

      searchResultDisplay =
        List.map createComponent model.searchResult.rows

      toolbarHeader =
        header [ class "toolbar toolbar-header" ] [ toolbarActions ]

      addFileButton =
        button [ class "btn btn-default", onClick AddFilesToDB, title "Add files to database" ] [ span [ class "icon icon-folder" ] [] ]

      toolButtons =
        div [ class "btn-group" ] [ addFileButton ]

      toolbarActions =
        div [ class "toolbar-actions" ] [ div [ class "btn-group" ] [ searchWindow ], toolButtons, span [] [ text model.serverMessage ] ]

      searchResultSummary =
        let
          totalPage =  model.searchResult.nHits // model.pagelen + 1
        in
          div [] [ div [] [ text ( (toString model.numResultPage) ++ " page of " ++ (toString totalPage) ) ]
                 , div [] [ text ((toString model.searchResult.nHits) ++ " hits." ) ]
                 ]

      pagenation =
        div [] [ button [ class "btn btn-default", onClick GetNextResultPage ] [ text "Next" ] ]

      sidebarContainer =
        div [ id "sidebar-container" ] [ div [ id "search" ]  ( List.append [ searchResultSummary, pagenation ] searchResultDisplay )  ]

      viewerIframe =
        iframe [ id "pdf-viewer", style [ ("width", "100%"), ("height", "100%") ], src "./pdfjs/web/viewer.html" ] []

      viewerContainer =
        div [ id "pdf-viewer-container" ] [ viewerIframe ]

      searchWindow =
        span [] [ input [ type_ "text", placeholder "Search", onInput SendSearch ] []
        , span [ style [ ("font-size", "15pt") ] ] [ text " " ]
        , span [ class "icon icon-search", style [ ("vertical-align", "middle"), ("font-size", "15pt") ] ] []
        ]

  in
      div []  [toolbarHeader, sidebarContainer, viewerContainer]

-- SUBSCRIPTIONS
--port filesToAddDB : (List String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [
    --filesToAddDB FilesToAddDB
  ]


-- HTTP

search : String -> Int -> Int -> Cmd Msg
search query numResultPage pagelen =
  let
      url =
        "http://localhost:8000/search?q=" ++ query ++ "&resultPage=" ++ (toString numResultPage) ++ "&pagelen=" ++ (toString pagelen)
  in
      Http.send NewSearchResult (Http.get url searchResponseDecoder)

