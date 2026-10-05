package com.meeplehearth.ai.client;

import io.netty.resolver.AddressResolver;
import io.netty.resolver.AddressResolverGroup;
import io.netty.resolver.InetNameResolver;
import io.netty.util.concurrent.EventExecutor;
import io.netty.util.concurrent.Promise;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.List;

/**
 * Netty address resolver used for every rulebook download connection. It resolves the host
 * itself and fails the resolution unless every address is a public unicast address
 * ({@link RulebookUrlValidator#isPublicAddress}).
 *
 * <p>Because the client connects to exactly the addresses returned here, the address that is
 * checked is the address that is used: a DNS answer that changes between
 * {@link RulebookUrlValidator#validate} and the connection (DNS rebinding) cannot steer the
 * download to an internal address. TLS SNI, certificate verification and the Host header still
 * use the original host name, since only name resolution is replaced.
 *
 * <p>Resolution is blocking ({@link InetAddress#getAllByName} by default), so the client using
 * this group runs on its own event loop.
 */
final class PublicAddressResolverGroup extends AddressResolverGroup<InetSocketAddress> {

    private final RulebookUrlValidator.HostResolver hostResolver;

    PublicAddressResolverGroup(RulebookUrlValidator.HostResolver hostResolver) {
        this.hostResolver = hostResolver;
    }

    @Override
    protected AddressResolver<InetSocketAddress> newResolver(EventExecutor executor) {
        return new PublicOnlyNameResolver(executor, hostResolver).asAddressResolver();
    }

    /** Resolves a host, rejecting it if any of its addresses is not public. */
    static List<InetAddress> resolvePublic(RulebookUrlValidator.HostResolver hostResolver, String host)
            throws UnknownHostException {
        InetAddress[] addresses = hostResolver.resolve(host);
        if (addresses == null || addresses.length == 0) {
            throw new UnknownHostException("Host could not be resolved: " + host);
        }
        for (InetAddress address : addresses) {
            if (!RulebookUrlValidator.isPublicAddress(address)) {
                throw new RulebookUrlValidator.UnsafeUrlException("Host resolves to a non-public address: " + host);
            }
        }
        return List.of(addresses);
    }

    static final class PublicOnlyNameResolver extends InetNameResolver {

        private final RulebookUrlValidator.HostResolver hostResolver;

        PublicOnlyNameResolver(EventExecutor executor, RulebookUrlValidator.HostResolver hostResolver) {
            super(executor);
            this.hostResolver = hostResolver;
        }

        @Override
        protected void doResolve(String inetHost, Promise<InetAddress> promise) {
            try {
                promise.setSuccess(resolvePublic(hostResolver, inetHost).get(0));
            } catch (Exception e) {
                promise.setFailure(e);
            }
        }

        @Override
        protected void doResolveAll(String inetHost, Promise<List<InetAddress>> promise) {
            try {
                promise.setSuccess(resolvePublic(hostResolver, inetHost));
            } catch (Exception e) {
                promise.setFailure(e);
            }
        }
    }
}
