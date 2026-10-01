FROM quay.io/operator-framework/opm:latest AS builder

COPY catalog /configs
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

FROM registry.access.redhat.com/ubi9/ubi-micro:latest
COPY --from=builder /configs /configs
COPY --from=builder /tmp/cache /tmp/cache
COPY --from=builder /bin/opm /bin/opm

EXPOSE 50051
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
