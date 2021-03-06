class MainController extends SimpleMVC.Controller
    _navigateToNewBounds: () =>
        # Clear existing markers and info windows if needed.
        if this._locations?
            for i in this._locations
                i.marker.setMap null
            this._locations.length = 0
        else
            this._locations = []
        
        mapBounds = this._map.getBounds()
        mapNE = mapBounds.getNorthEast()
        mapSW = mapBounds.getSouthWest()
        
        query = $.ajax "/businesses/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng()
        self = this
        query.done (data) ->
            for i in data
                # TODO: ick. Use views for this.
                checked = ""
                if i.pin_enabled == "true"
                    checked = "checked"
                windowContents = '<div id="emvBusinessInfo">' +
                    '<div class="add-name">' + i.name + '</div>' +
                    '<div class="add-address"><address>' + i.address + '</address></div>' +
                    '<div class="add-options"><input type="checkbox" id="pinEnabled" value="true" ' + checked  + ' disabled /><label for="pinEnabled">business has PIN pad</label></div>' +
                    '<div class="add-toolbar"><a href="#" onclick="event.preventDefault(); window.app.reportError(' + i.id + ');">report errors</a></div></div>'
                    
                newMarker = {
            	    marker: new google.maps.Marker({
            	        position: new google.maps.LatLng(i.lat, i.lng),
            	        map: self._map
            	    }),
            	    infoWindow: new google.maps.InfoWindow({
            	        content: windowContents
            	    })
                }
                aMarker = newMarker.marker
                aMarker._____refToSelf = newMarker
                google.maps.event.addListener aMarker, "click", () ->
                    this._____refToSelf.infoWindow.open self._map, this._____refToSelf.marker
                self._locations.push newMarker
       
            if self._handlePossibleAdd
                self._handlePossibleAdd = false 
                found = false
                for i in self._locations
                    if i.marker.getPosition().lat() == self._place.geometry.location.lat() and i.marker.getPosition().lng() == self._place.geometry.location.lng()
                        i.infoWindow.open self._map, i.marker
                        found = true

                if not found
                    # TODO: ick. We should be using SimpleMVC views to render the popup.
                    contentString = '<div id="emvBusinessInfo">' +
                        '<div class="add-name"><input type="text" id="businessName" placeholder="Name of the business" /></div>' +
                        '<div class="add-address"><address id="businessAddress">' + self._place.formatted_address + '</address></div>' +
                        '<div class="add-options"><input type="checkbox" id="pinEnabled" value="true"/><label for="pinEnabled">business has PIN pad</label></div>' +
                        '<div class="add-toolbar"><a href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a></div></div>'
        
                    if self._infoWindow?
                        self._infoWindow.close()
        
                    self._infoWindow = new google.maps.InfoWindow({
                        content: contentString,
                        position: self._place.geometry.location
                    })
                    self._infoWindow.open self._map

    _navigateToAddress: () =>
        # Ensure event isn't called multiple times.
        google.maps.event.clearListeners this._map, "bounds_changed"

        this._place = this._autocomplete.getPlace()
        placeLoc = this._place.geometry.location
        window.app.navigate "/loc/" + placeLoc.lat() + "/" + placeLoc.lng(), true, false
        this._handlePossibleAdd = true
        google.maps.event.addListener this._map, "bounds_changed", this._navigateToNewBounds
        this._map.setZoom 15
    
    reportError: (id) ->
        result = ""
        while result == ""
        	result = window.prompt("Enter reason for reporting this entry:")
        if result != null
            query = $.ajax "/businesses/report/" + id, {type: "POST", data: {
            	reason: result
            }}
            query.done () ->
                $("#emvBusinessInfo .add-toolbar").text("reported")
                
    addBusiness: () ->
        self = this;
        request = $.ajax "/businesses/add", {type: "POST", data: {
        	name: $("#businessName").val(),
        	address: $("#businessAddress").text(),
        	latitude: this._place.geometry.location.lat(),
        	longitude: this._place.geometry.location.lng(),
        	pin_enabled: $("#pinEnabled").prop("checked")
        }}
        request.done (data) ->
            self._infoWindow.close()
        	
            # TODO: ick. Use views for this.
            checked = ""
            if data.pin_enabled == "true"
                checked = "checked"
            windowContents = '<div id="emvBusinessInfo">' +
                '<div class="add-name">' + data.name + '</div>' +
                '<div class="add-address"><address>' + data.address + '</address></div>' +
                '<div class="add-options"><input type="checkbox" id="pinEnabled" value="true" ' + checked + ' disabled /><label for="pinEnabled">business has PIN pad</label></div>' +
                '<div class="add-toolbar"><a href="#" onclick="event.preventDefault(); window.app.reportError(' + data.id + ');">report errors</a></div></div>'
                
            newMarker = {
        	    marker: new google.maps.Marker({
        	        position: new google.maps.LatLng(data.lat, data.lng),
        	        map: self._map
        	    }),
        	    infoWindow: new google.maps.InfoWindow({
        	        content: windowContents
        	    })
            }
            google.maps.event.addListener newMarker.marker, "click", () ->
                newMarker.infoWindow.open self._map, newMarker.marker
            self._locations.push newMarker
    
    @route "loc/:lat/:long", (lat, lng) ->
        mapOptions = {
            zoom: 8,
            center: new google.maps.LatLng(lat, lng),
            noClear: true
        }
        if not this._map?
            this._map = new google.maps.Map(document.getElementById("map-canvas"), mapOptions)
        	
            # handler so we can reload the list
            google.maps.event.addListener this._map, "bounds_changed", this._navigateToNewBounds
        
            # initialize autocomplete widget
            this._autocomplete = new google.maps.places.Autocomplete(document.getElementById("address"))
            google.maps.event.addListener this._autocomplete, 'place_changed', this._navigateToAddress
        else
            this._map.panTo mapOptions.center
        
 
    @route "", () ->
        # Navigate to center of the US to start. Geolocation will move us to the correct location later.
        failFn = (errObj) ->
            window.app.navigate "/loc/39.828175/-98.579500", true, false
        failFn()

        setTimeout(() ->
            if navigator.geolocation?
                successFn = (pos) ->
                    window.app.navigate "/loc/" + pos.coords.latitude + "/" + pos.coords.longitude, true, false
                
                navigator.geolocation.getCurrentPosition successFn, () -> {}
        , 0)
        	
# initialize app
$(document).ready () ->
    window.app = new MainController
    window.app.start()
