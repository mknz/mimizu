module SearchView exposing (..)

import Html exposing (Html, program, text, button, h1, h2, div, input, a, span, p, header, iframe, nav)
import Html.Attributes exposing (class, id, type_, placeholder, value, href, style, src, title, size)
import Html.Events exposing (onClick, onInput)
import Markdown

import Models exposing (Model)
import Messages exposing (Msg(..))

import ViewCommonComponents exposing (toolbarHeader, viewerContainer, pagenation)

searchView : Model -> Html Msg
searchView model =
  let
    createComponent row =
      let
        sBody = row.title ++ " (p" ++ toString row.numPage ++  "): " ++ row.body
      in
        div [] [ div [ class "search-result", onClick (OpenDocument (row.fileName, row.numPage)) ] [ Markdown.toHtml [] sBody ]
        ]

    resultDisplay =
      List.map createComponent model.searchResult.rows

    resultSummary =
      let
        resPageStr = (toString model.numResultPage) ++ " page of " ++ (toString model.numTotalPage)
        hitsStr = "(" ++ (toString model.numArticles) ++ " hits" ++ ")"

        summary =
          if model.numTotalPage == 0 then
            ""
          else
            resPageStr ++ " " ++ hitsStr
      in
        div [] [ div [ style [ ("height", "15px") ] ] [ text summary ] ]

    sidebarContainer =
      div [ id "sidebar-container" ] [ div [ id "search" ]  ( List.append [ (pagenation model.numResultPage model.numTotalPage model.numArticles), resultSummary ] resultDisplay )  ]

  in
    div []  [toolbarHeader model.viewMode model.serverMessage, sidebarContainer, viewerContainer]