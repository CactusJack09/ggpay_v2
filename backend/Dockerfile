FROM dart:stable

WORKDIR /app

COPY . .

RUN dart pub get

EXPOSE 3000

CMD ["dart", "run", "bin/server.dart"]
