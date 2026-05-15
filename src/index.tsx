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

export type RTLEnvironment = 'staging' | 'production';

export type RTLInitializeOptions = {
  program: string;
  environment: RTLEnvironment;
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

export type RTLTokenRequestEvent = {
  requestId: string;
};

export type RTLOpenUrlEvent = {
  url: string;
  forceExternal: boolean;
};

export type RTLAuthenticatedEvent = {
  accessToken: string;
  refreshToken: string;
};

export type RTLLocationPermissionChangeEvent = {
  granted: boolean;
};

export type RTLGeofenceEnterEvent = {
  store: Record<string, unknown>;
};

type RTLSdkNativeModule = {
  initialize(options: RTLInitializeOptions): Promise<void>;
  presentExperience(options?: RTLExperienceOptions): Promise<RTLExperienceResult>;
  login(token: string, options?: RTLExperienceOptions): Promise<RTLExperienceResult>;
  logout(): void;
  enableLocationFeatures(): Promise<void>;
  disableLocationFeatures(): void;
  isLoggedIn(): Promise<boolean | null>;
  hasLocationPermission(): Promise<boolean>;
  provideToken(requestId: string, token?: string | null): void;
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

const NativeRTLView = requireNativeComponent<ViewProps>('RTLView') as HostComponent<ViewProps>;

export function RTLView(props: ViewProps) {
  return <NativeRTLView {...props} />;
}

const onNeedsToken = (listener: (event: RTLTokenRequestEvent) => void): EmitterSubscription =>
  eventEmitter.addListener('onNeedsToken', listener);

const onReady = (listener: () => void): EmitterSubscription =>
  eventEmitter.addListener('onReady', listener);

const onAuthenticated = (listener: (event: RTLAuthenticatedEvent) => void): EmitterSubscription =>
  eventEmitter.addListener('onAuthenticated', listener);

const onLogout = (listener: () => void): EmitterSubscription =>
  eventEmitter.addListener('onLogout', listener);

const onOpenUrl = (listener: (event: RTLOpenUrlEvent) => void): EmitterSubscription =>
  eventEmitter.addListener('onOpenUrl', listener);

const onLocationPermissionChange = (
  listener: (event: RTLLocationPermissionChangeEvent) => void
): EmitterSubscription => eventEmitter.addListener('onLocationPermissionChange', listener);

const onGeofenceEnter = (listener: (event: RTLGeofenceEnterEvent) => void): EmitterSubscription =>
  eventEmitter.addListener('onGeofenceEnter', listener);

export const RTL = {
  initialize(options: RTLInitializeOptions) {
    return NativeRTLSdk.initialize(options);
  },

  presentExperience(options?: RTLExperienceOptions) {
    return NativeRTLSdk.presentExperience(options ?? {});
  },

  login(token: string, options?: RTLExperienceOptions) {
    return NativeRTLSdk.login(token, options ?? {});
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

  isLoggedIn() {
    return NativeRTLSdk.isLoggedIn();
  },

  hasLocationPermission() {
    return NativeRTLSdk.hasLocationPermission();
  },

  provideToken(requestId: string, token?: string | null) {
    NativeRTLSdk.provideToken(requestId, token ?? null);
  },

  onNeedsToken,
  onReady,
  onAuthenticated,
  onLogout,
  onOpenUrl,
  onLocationPermissionChange,
  onGeofenceEnter,

  addTokenRequestListener: onNeedsToken,
  addReadyListener: onReady,
  addAuthenticatedListener: onAuthenticated,
  addLogoutListener: onLogout,
  addOpenUrlListener: onOpenUrl,
  addLocationPermissionChangeListener: onLocationPermissionChange,
  addGeofenceEnterListener: onGeofenceEnter,
};

export default RTL;
