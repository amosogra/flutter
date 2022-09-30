/*
  mDNS Plugin Example
  Flutter client demonstrating browsing for Chromecasts
  on your local network

  Copyright (c) David Thorpe 2019
  Please see the LICENSE file for licensing information
*/

import 'package:bloc/bloc.dart';

import 'package:mdns_plugin/mdns_plugin.dart';
import 'package:mdns_plugin_example/src/models/service_list.dart';

/////////////////////////////////////////////////////////////////////
// EVENT

enum AppEventDiscoveryState { Started, Stopped, Restart }

enum AppEventServiceState { Found, Resolved, Updated, Removed }

abstract class AppEvent {}

class AppEventStart extends AppEvent {
  @override
  String toString() => 'AppEventStart';
}

class AppEventDiscovery extends AppEvent {
  AppEventDiscoveryState state;

  // CONSTRUCTOR ////////////////////////////////////////////////////

  AppEventDiscovery(this.state);

  // GETTERS AND SETTERS ////////////////////////////////////////////

  @override
  String toString() => 'AppEventDiscovery($state)';
}

class AppEventService extends AppEvent {
  AppEventServiceState state;
  MDNSService service;

  // CONSTRUCTOR ////////////////////////////////////////////////////

  AppEventService(this.state, this.service);

  // GETTERS AND SETTERS ////////////////////////////////////////////

  @override
  String toString() => 'AppEventService($state,$service)';
}

/////////////////////////////////////////////////////////////////////
// STATE

enum AppStateAction { ShowToast }

abstract class AppState {}

class AppStateUninitialized extends AppState {
  @override
  String toString() => 'AppStateUninitialized';
}

class AppStarted extends AppState {
  @override
  String toString() => 'AppStarted';
}

class AppUpdated extends AppState {
  ServiceList services;
  MDNSService service;
  AppStateAction action;

  // CONSTRUCTOR ////////////////////////////////////////////////////

  AppUpdated(this.services, {this.service, this.action});

  // GETTERS AND SETTERS ////////////////////////////////////////////

  @override
  String toString() => 'AppUpdated($service,$action)';
}

/////////////////////////////////////////////////////////////////////
// BLOC

class AppBloc extends Bloc<AppEvent, AppState> implements MDNSPluginDelegate {
  final String serviceType = "_googlecast._tcp";
  MDNSPlugin _mdns;
  ServiceList _services = ServiceList();
  AppBloc() : super(AppStateUninitialized()) {
    on<AppEventStart>(_onAppEventStart);
    on<AppEventDiscovery>(_onAppEventDiscovery);
    on<AppEventService>(_onAppEventService);
  }

  // EVENT MAPPING //////////////////////////////////////////////////

  Future<void> _onAppEventStart(AppEventStart event, Emitter<AppState> emit) {
    // Start discovery
    _mdns = MDNSPlugin(this);
    _mdns.startDiscovery(serviceType, enableUpdating: true);
  }

  Future<void> _onAppEventDiscovery(AppEventDiscovery event, Emitter<AppState> emit) {
    // Remove all services and update the application
    _services.removeAll();
    // If restart then call discovery again
    if (event.state == AppEventDiscoveryState.Restart) {
      _mdns.startDiscovery(serviceType);
      emit(AppUpdated(_services, action: AppStateAction.ShowToast));
    } else {
      emit(AppUpdated(_services));
    }
  }

  Future<void> _onAppEventService(AppEventService event, Emitter<AppState> emit) {
    switch (event.state) {
      case AppEventServiceState.Found:
        // We don't add the service when it's found, but only when
        // it's resolved or updated
        break;
      case AppEventServiceState.Resolved:
        _services.update(event.service);
        break;
      case AppEventServiceState.Updated:
        _services.update(event.service);
        break;
      case AppEventServiceState.Removed:
        _services.remove(event.service);
        break;
    }
    emit(AppUpdated(_services, service: event.service));
  }

  /* @override
  Stream<AppState> mapEventToState(AppEvent event) async* {
    if (event is AppEventStart) {
      // Start discovery
      _mdns = MDNSPlugin(this);
      _mdns.startDiscovery(serviceType, enableUpdating: true);
    }

    if (event is AppEventDiscovery) {
      // Remove all services and update the application
      _services.removeAll();
      // If restart then call discovery again
      if (event.state == AppEventDiscoveryState.Restart) {
        _mdns.startDiscovery(serviceType);
        yield AppUpdated(_services, action: AppStateAction.ShowToast);
      } else {
        yield AppUpdated(_services);
      }
    }

    if (event is AppEventService) {
      switch (event.state) {
        case AppEventServiceState.Found:
          // We don't add the service when it's found, but only when
          // it's resolved or updated
          break;
        case AppEventServiceState.Resolved:
          _services.update(event.service);
          break;
        case AppEventServiceState.Updated:
          _services.update(event.service);
          break;
        case AppEventServiceState.Removed:
          _services.remove(event.service);
          break;
      }
      yield AppUpdated(_services, service: event.service);
    }
  } */

  // MDNS PLUGIN DELEGATE  //////////////////////////////////////////

  void onDiscoveryStarted() => this.add(AppEventDiscovery(AppEventDiscoveryState.Started));
  void onDiscoveryStopped() => this.add(AppEventDiscovery(AppEventDiscoveryState.Stopped));
  bool onServiceFound(MDNSService service) {
    this.add(AppEventService(AppEventServiceState.Found, service));
    // Always resolve services which have been found
    return true;
  }

  void onServiceResolved(MDNSService service) => this.add(AppEventService(AppEventServiceState.Resolved, service));
  void onServiceUpdated(MDNSService service) => this.add(AppEventService(AppEventServiceState.Updated, service));
  void onServiceRemoved(MDNSService service) => this.add(AppEventService(AppEventServiceState.Removed, service));

  // GETTERS AND SETTERS ////////////////////////////////////////////
}
