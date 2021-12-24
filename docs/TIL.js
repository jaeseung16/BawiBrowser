/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


window.addEventListener('cloudkitloaded', function() {
  console.log("listening for cloudkitloaded");
  CloudKit.configure({
    containers: [{
      containerIdentifier: 'iCloud.com.resonance.jlee.BawiBrowser',
      apiTokenAuth: {
        // And generate a web token through CloudKit Dashboard.
        apiToken: 'edfc5a34519c89fa1b0f80f2e37fac5d71fb5709cc6c4cc90425955ed08110f6',
        persist: true // Sets a cookie.
      },
      environment: 'production',
      signInButton: { id: 'sign-in-button', theme: 'black' },
      signOutButton: { id: 'sign-out-button', theme: 'black' }
    }]
  });
  console.log("cloudkitloaded");
                        
  function TILViewModel() {
    var self = this;
    console.log("get default container");
    var container = CloudKit.getDefaultContainer();

    console.log("set privateDB");
    var privateDB = container.privateCloudDatabase;
    self.items = ko.observableArray();
    
    // Fetch public records
    self.fetchRecords = function() {
      console.log("fetching records from " + privateDB);
      var query = { recordType: 'CD_Article', sortBy: [{ fieldName: 'CD_created', "ascending": false}] };
      
      var options = {};
      options.zoneId = { zoneName: "com.apple.coredata.cloudkit.zone" };
      // Execute the query.
      return privateDB.performQuery(query, options).then(function(response) {
        console.log("performQuery");
        if(response.hasErrors) {
          console.error(response.errors[0]);
          return;
        }
        var records = response.records;
        var numberOfRecords = records.length;
        if (numberOfRecords === 0) {
          console.error('No matching items');
          return;
        }
        console.log(records);
        self.items(records);
      });
    };

    self.displayUserName = ko.observable('Unauthenticated User');
    self.gotoAuthenticatedState = function(userInfo) {
      if(userInfo.isDiscoverable) {
        self.displayUserName(userInfo.firstName + ' ' + userInfo.lastName);
      } else {
        self.displayUserName('User Who Must Not Be Named');
      }
      
      container
      .whenUserSignsOut()
      .then(self.gotoUnauthenticatedState);
      console.log("fetchRecords");
      self.fetchRecords();
    };

    self.gotoUnauthenticatedState = function(error) {
      self.displayUserName('Unauthenticated User');
    
      container
      .whenUserSignsIn()
      .then(self.gotoAuthenticatedState)
      .catch(self.gotoUnauthenticatedState);
    };
    
    container.setUpAuth().then(function(userInfo) {
      console.log("setUpAuth");
      if(userInfo) {
        console.log("gotoAuthenticatedState");
        self.gotoAuthenticatedState(userInfo);
       } else {
        console.log("gotoUnauthenticatedState");
        self.gotoUnauthenticatedState();
       }

      //self.fetchRecords();  // Don't need user auth to fetch public records
    });

  }
  
  ko.applyBindings(new TILViewModel());
});

