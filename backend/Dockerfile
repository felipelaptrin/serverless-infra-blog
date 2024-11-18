FROM golang:1.23-alpine as build
WORKDIR /app
COPY go.mod go.sum ./
COPY . .
RUN go mod download && go mod verify
RUN go build -o main main.go


FROM alpine:3.20
COPY --from=build /app/main /main
ENTRYPOINT [ "/main" ]