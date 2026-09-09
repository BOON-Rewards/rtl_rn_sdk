import React from 'react';
import {
  NativeEventEmitter,
  NativeModules,
  Platform,
  requireNativeComponent,
  type EmitterSubscription,
  type HostComponent,
  type ViewProps,
} from 'react-native';

export type RTLAuthTokenProvider = () =>
  | Promise<string | null>
  | string
  | null;

export type RTLInitializeOptions = {
  baseUrl: string;
  urlScheme: string;
  externalChapterId?: string;
  authTokenProvider: RTLAuthTokenProvider;
};

type RTLNativeInitializeOptions = {
  baseUrl: string;
  urlScheme: string;
  externalChapterId?: string;
};

export type RTLExperienceOptions = {
  rtlEventId?: string;
  rtlRedirectUrl?: string;
};

export type RTLExperienceResult = {
  success: boolean;
  errorCode?: string | null;
};

type RTLAuthTokenRequestEvent = {
  requestId: string;
};

export type RTLLocationPermissionChangeEvent = {
  granted: boolean;
};

type RTLLoadingStateChangeEvent = {
  isLoading: boolean;
};

export type RTLGeofenceEnterEvent = {
  store: Record<string, unknown>;
};

type RTLSdkNativeModule = {
  initialize(options: RTLNativeInitializeOptions): Promise<void>;
  presentExperience(options?: RTLExperienceOptions): Promise<RTLExperienceResult>;
  handleDeepLink(url: string): Promise<boolean>;
  logout(): void;
  enableLocationFeatures(): Promise<void>;
  disableLocationFeatures(): void;
  hasLocationPermission(): Promise<boolean>;
  resolveAuthTokenRequest(requestId: string, token: string | null): void;
};

const LINKING_ERROR =
  `The package 'react-native-rtl-sdk' is not linked. Make sure:\n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the native app after installing the package\n';

const NativeRTLSdk = NativeModules.RTLSdk as RTLSdkNativeModule | undefined;

if (!NativeRTLSdk) {
  throw new Error(LINKING_ERROR);
}

const eventEmitter = new NativeEventEmitter(NativeModules.RTLSdk);
let authTokenSubscription: EmitterSubscription | null = null;

// NativeEventEmitter exposes untyped payloads; keep our native event contract here.
type RTLEventMap = {
  onLoadingStateChanged: RTLLoadingStateChangeEvent;
  onLocationPermissionChange: RTLLocationPermissionChangeEvent;
  onGeofenceEnter: RTLGeofenceEnterEvent;
  authTokenRequested: RTLAuthTokenRequestEvent;
};

function subscribe<K extends keyof RTLEventMap>(
  name: K,
  listener: (event: RTLEventMap[K]) => unknown
): EmitterSubscription {
  return eventEmitter.addListener(name, (event: unknown) =>
    listener(event as RTLEventMap[K])
  );
}


const NativeRTLView = requireNativeComponent<ViewProps>('RTLView') as HostComponent<ViewProps>;

export function RTLView(props: ViewProps) {
  return <NativeRTLView {...props} />;
}

const onReady = (listener: () => void): EmitterSubscription =>
  eventEmitter.addListener('onReady', listener);

const onLoadingStateChanged = (
  listener: (isLoading: boolean) => void
): EmitterSubscription =>
  subscribe(
    'onLoadingStateChanged',
    (event: RTLLoadingStateChangeEvent) => listener(event.isLoading)
  );

const onLocationPermissionChange = (
  listener: (event: RTLLocationPermissionChangeEvent) => void
): EmitterSubscription => subscribe('onLocationPermissionChange', listener);

const onGeofenceEnter = (listener: (event: RTLGeofenceEnterEvent) => void): EmitterSubscription =>
  subscribe('onGeofenceEnter', listener);

export const RTL = {
  initialize(options: RTLInitializeOptions) {
    const { authTokenProvider, ...nativeOptions } = options;
    if (typeof authTokenProvider !== 'function') {
      return Promise.reject(new Error('authTokenProvider is required'));
    }

    authTokenSubscription?.remove();
    const subscription = subscribe(
      'authTokenRequested',
      async (event: RTLAuthTokenRequestEvent) => {
        let token: string | null = null;
        try {
          const providedToken = await authTokenProvider();
          token = typeof providedToken === 'string' ? providedToken : null;
        } catch {
          token = null;
        }
        NativeRTLSdk.resolveAuthTokenRequest(event.requestId, token);
      }
    );
    authTokenSubscription = subscription;

    const initialization = NativeRTLSdk.initialize(nativeOptions);
    return initialization.catch(error => {
      if (authTokenSubscription === subscription) {
        subscription.remove();
        authTokenSubscription = null;
      }
      throw error;
    });
  },

  presentExperience(options?: RTLExperienceOptions) {
    return NativeRTLSdk.presentExperience(options ?? {});
  },

  handleDeepLink(url: string) {
    return NativeRTLSdk.handleDeepLink(url);
  },

  logout() {
    NativeRTLSdk.logout();
  },

  enableLocationFeatures() {
    return NativeRTLSdk.enableLocationFeatures();
  },

  disableLocationFeatures() {
    NativeRTLSdk.disableLocationFeatures();
  },

  hasLocationPermission() {
    return NativeRTLSdk.hasLocationPermission();
  },

  onReady,
  onLoadingStateChanged,
  onLocationPermissionChange,
  onGeofenceEnter,
};

export default RTL;
