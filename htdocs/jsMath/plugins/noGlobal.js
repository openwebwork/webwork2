/*
 *  noGlobal.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file disables the Go Global button.  It should be loaded
 *  BEFORE jsMath.js.
 *
 *  ---------------------------------------------------------------------
 *
 *  Copyright 2006 by Davide P. Cervone
 * 
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

if (!window.jsMath) {window.jsMath = {}}
if (!jsMath.Controls) {jsMath.Controls = {}}
if (!jsMath.Controls.cookie) {jsMath.Controls.cookie = {}}

jsMath.noGoGlobal = 1;
jsMath.noChangeGlobal = 1;
jsMath.noShowGlobal = 1;
jsMath.Controls.cookie.global = 'never';
