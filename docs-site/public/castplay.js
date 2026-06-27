/* castplay.js — a tiny, self-contained asciinema-cast player.
   No dependencies, no CDN. Parses an asciinema v2 .cast (header + [t,"o",text] events),
   types it into a styled terminal element with ANSI-SGR colour, autoplays when its slide
   becomes visible, auto-scrolls like a real terminal. Click to pause/resume; click when
   finished to replay. */
(function () {
  var COL = { 32:'#7fd1a0', 90:'#8b857a', 37:'#cfc7b6', 92:'#8fe3a8',
              91:'#ff8a76', 33:'#f4bf4f', 36:'#79c7d6', 97:'#ffffff' };
  function esc(s){ return s.replace(/[&<>]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;'}[c]; }); }
  function ansiToHtml(raw){
    var out='', open=false, color=null, bold=false;
    var re=/\x1b\[([0-9;]*)m/g, last=0, m;
    function span(){ var css=''; if(color)css+='color:'+color+';'; if(bold)css+='font-weight:700;'; return css?'<span style="'+css+'">':'<span>'; }
    function chunk(text){ if(!text)return; if(!open){out+=span();open=true;} out+=esc(text); }
    while((m=re.exec(raw))){
      chunk(raw.slice(last,m.index)); last=re.lastIndex;
      if(open){out+='</span>';open=false;}
      m[1].split(';').forEach(function(code){ code=parseInt(code||'0',10);
        if(code===0){color=null;bold=false;} else if(code===1){bold=true;} else if(COL[code]){color=COL[code];} });
    }
    chunk(raw.slice(last)); if(open)out+='</span>';
    return out.replace(/\r\n/g,'\n');
  }

  function Player(el){
    this.el=el; this.src=el.getAttribute('data-cast'); this.events=null;
    this.timer=null; this.i=0; this.raw=''; this.playing=false; this.paused=false; this.finished=false;
    var self=this;
    el.style.cursor='pointer';
    el.addEventListener('click', function(){
      if(self.finished) self.replay();
      else if(self.playing) self.pause();
      else if(self.paused) self.resume();
      else self.play();
    });
  }
  Player.prototype.load=function(cb){
    if(this.events) return cb();
    var self=this;
    fetch(this.src).then(function(r){return r.text();}).then(function(txt){
      self.events=txt.split('\n').filter(Boolean).slice(1).map(function(l){return JSON.parse(l);}); cb();
    }).catch(function(){ self.el.textContent='(cast failed to load)'; });
  };
  Player.prototype.render=function(raw){ this.el.innerHTML=ansiToHtml(raw); this.el.scrollTop=this.el.scrollHeight; };
  Player.prototype._tick=function(){
    var self=this, ev=this.events;
    if(this.i>=ev.length){ this.playing=false; this.finished=true; return; }
    this.raw+=ev[this.i][2]; this.render(this.raw);
    var cur=ev[this.i][0], nxt=(this.i+1<ev.length)?ev[this.i+1][0]:cur; this.i++;
    this.timer=setTimeout(function(){ self._tick(); }, Math.max(0,(nxt-cur)*1000));
  };
  Player.prototype.play=function(){ var self=this; if(this.playing)return; this.load(function(){ self.playing=true; self.paused=false; self.finished=false; self._tick(); }); };
  Player.prototype.pause=function(){ clearTimeout(this.timer); this.playing=false; this.paused=true; };
  Player.prototype.resume=function(){ if(this.playing)return; this.playing=true; this.paused=false; this._tick(); };
  Player.prototype.reset=function(){ clearTimeout(this.timer); this.i=0; this.raw=''; this.playing=false; this.paused=false; this.finished=false; this.render(''); };
  Player.prototype.replay=function(){ this.reset(); this.play(); };

  function init(){
    var players=[].slice.call(document.querySelectorAll('[data-cast]')).map(function(n){ return new Player(n); });
    // Respect prefers-reduced-motion: render the final frame instantly
    // instead of typing it. (Added for the Seams docs site; not in the
    // upstream presentations copy.) Clicking still replays on demand.
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if(reduce){
      players.forEach(function(p){ p.load(function(){
        p.raw = p.events.map(function(e){ return e[2]; }).join('');
        p.render(p.raw); p.finished = true;
      }); });
      window.__castPlayers=players; return;
    }
    if('IntersectionObserver' in window){
      var io=new IntersectionObserver(function(es){
        es.forEach(function(e){ var p=e.target.__cp; if(!p)return;
          if(e.isIntersecting){ if(!p.armed){ p.armed=true; p.replay(); } }
          else { p.armed=false; p.reset(); }
        });
      },{threshold:.55});
      players.forEach(function(p){ p.el.__cp=p; io.observe(p.el); });
    } else { players.forEach(function(p){ p.play(); }); }
    window.__castPlayers=players;
  }
  if(document.readyState!=='loading') init(); else document.addEventListener('DOMContentLoaded', init);
})();
