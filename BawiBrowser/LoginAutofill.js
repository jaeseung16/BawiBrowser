
function LoginAutofill_EnableAutofill(id) {
    var login = document.getElementById("login_id");
    login.value = id;
    
    var password = document.getElementById("login_passwd");
    password.setAttribute("autocomplete", "current-password");
    
    return true
}
