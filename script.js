/* ==========================================
   PORTFOLIO - Main JavaScript
   Murathan Mollamehmetoğlu
   ========================================== */

// ==========================================
// PARTICLE BACKGROUND
// ==========================================
class ParticleBackground {
    constructor() {
        this.canvas = document.getElementById('particles-canvas');
        this.ctx = this.canvas.getContext('2d');
        this.particles = [];
        this.mouse = { x: null, y: null, radius: 150 };
        this.init();
    }

    init() {
        this.resize();
        this.createParticles();
        this.animate();
        
        window.addEventListener('resize', () => this.resize());
        window.addEventListener('mousemove', (e) => {
            this.mouse.x = e.x;
            this.mouse.y = e.y;
        });
    }

    resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    createParticles() {
        const count = Math.min(80, Math.floor((this.canvas.width * this.canvas.height) / 15000));
        this.particles = [];
        for (let i = 0; i < count; i++) {
            this.particles.push({
                x: Math.random() * this.canvas.width,
                y: Math.random() * this.canvas.height,
                size: Math.random() * 2 + 0.5,
                speedX: (Math.random() - 0.5) * 0.5,
                speedY: (Math.random() - 0.5) * 0.5,
                opacity: Math.random() * 0.5 + 0.1,
                color: Math.random() > 0.5 ? '108, 92, 231' : '0, 206, 201'
            });
        }
    }

    animate() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        this.particles.forEach((p, i) => {
            // Move particles
            p.x += p.speedX;
            p.y += p.speedY;

            // Boundary check
            if (p.x < 0 || p.x > this.canvas.width) p.speedX *= -1;
            if (p.y < 0 || p.y > this.canvas.height) p.speedY *= -1;

            // Mouse interaction
            if (this.mouse.x !== null) {
                const dx = this.mouse.x - p.x;
                const dy = this.mouse.y - p.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < this.mouse.radius) {
                    const force = (this.mouse.radius - dist) / this.mouse.radius;
                    p.x -= dx * force * 0.02;
                    p.y -= dy * force * 0.02;
                }
            }

            // Draw particle
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            this.ctx.fillStyle = `rgba(${p.color}, ${p.opacity})`;
            this.ctx.fill();

            // Connect nearby particles
            for (let j = i + 1; j < this.particles.length; j++) {
                const p2 = this.particles[j];
                const dx = p.x - p2.x;
                const dy = p.y - p2.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < 120) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(p.x, p.y);
                    this.ctx.lineTo(p2.x, p2.y);
                    this.ctx.strokeStyle = `rgba(108, 92, 231, ${0.08 * (1 - dist / 120)})`;
                    this.ctx.lineWidth = 0.5;
                    this.ctx.stroke();
                }
            }
        });

        requestAnimationFrame(() => this.animate());
    }
}

// ==========================================
// NAVIGATION
// ==========================================
class Navigation {
    constructor() {
        this.navbar = document.getElementById('navbar');
        this.navToggle = document.getElementById('nav-toggle');
        this.navLinks = document.getElementById('nav-links');
        this.links = document.querySelectorAll('.nav-link');
        this.sections = document.querySelectorAll('section');
        this.init();
    }

    init() {
        // Scroll effect
        window.addEventListener('scroll', () => this.onScroll());
        
        // Mobile toggle
        this.navToggle.addEventListener('click', () => this.toggleMenu());
        
        // Smooth scroll & close menu
        this.links.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const targetId = link.getAttribute('href');
                const target = document.querySelector(targetId);
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth' });
                    this.closeMenu();
                }
            });
        });
    }

    onScroll() {
        const scrollY = window.scrollY;
        
        // Navbar background
        if (scrollY > 50) {
            this.navbar.classList.add('scrolled');
        } else {
            this.navbar.classList.remove('scrolled');
        }

        // Active link
        this.sections.forEach(section => {
            const top = section.offsetTop - 100;
            const bottom = top + section.offsetHeight;
            const id = section.getAttribute('id');
            
            if (scrollY >= top && scrollY < bottom) {
                this.links.forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${id}`) {
                        link.classList.add('active');
                    }
                });
            }
        });
    }

    toggleMenu() {
        this.navToggle.classList.toggle('active');
        this.navLinks.classList.toggle('active');
    }

    closeMenu() {
        this.navToggle.classList.remove('active');
        this.navLinks.classList.remove('active');
    }
}

// ==========================================
// SCROLL REVEAL ANIMATIONS
// ==========================================
class ScrollReveal {
    constructor() {
        this.init();
    }

    init() {
        // Add reveal class to elements
        const revealElements = [
            '.about-card',
            '.timeline-item',
            '.skill-card',
            '.project-card',
            '.contact-card',
            '.contact-form',
            '.skills-interests'
        ];

        revealElements.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
                el.classList.add('reveal');
            });
        });

        // Observe
        const observer = new IntersectionObserver((entries) => {
            entries.forEach((entry, index) => {
                if (entry.isIntersecting) {
                    setTimeout(() => {
                        entry.target.classList.add('visible');
                    }, index * 100);
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        });

        document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
    }
}

// ==========================================
// SKILL BAR ANIMATION
// ==========================================
class SkillBars {
    constructor() {
        this.init();
    }

    init() {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const bar = entry.target;
                    const width = bar.getAttribute('data-width');
                    setTimeout(() => {
                        bar.style.width = `${width}%`;
                    }, 300);
                    observer.unobserve(bar);
                }
            });
        }, { threshold: 0.5 });

        document.querySelectorAll('.skill-progress').forEach(bar => observer.observe(bar));
    }
}

// ==========================================
// COUNTER ANIMATION
// ==========================================
class CounterAnimation {
    constructor() {
        this.init();
    }

    init() {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    this.animateCounter(entry.target);
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.5 });

        document.querySelectorAll('.stat-number').forEach(el => observer.observe(el));
    }

    animateCounter(element) {
        const target = parseInt(element.getAttribute('data-target'));
        const duration = 2000;
        const start = performance.now();

        const update = (currentTime) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            
            // Easing
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = Math.floor(eased * target);
            
            element.textContent = current;
            
            if (progress < 1) {
                requestAnimationFrame(update);
            } else {
                element.textContent = target;
            }
        };

        requestAnimationFrame(update);
    }
}

// ==========================================
// CONTACT FORM
// ==========================================
class ContactForm {
    constructor() {
        this.form = document.getElementById('contact-form');
        this.init();
    }

    init() {
        if (!this.form) return;
        
        this.form.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleSubmit();
        });
    }

    handleSubmit() {
        const btn = this.form.querySelector('#submit-btn');
        const originalContent = btn.innerHTML;
        
        // Show loading
        btn.innerHTML = '<span>Gönderiliyor...</span>';
        btn.disabled = true;
        btn.style.opacity = '0.7';

        // Simulate sending
        setTimeout(() => {
            btn.innerHTML = '<span>✓ Mesajınız Gönderildi!</span>';
            btn.style.background = 'linear-gradient(135deg, #00b894, #00cec9)';
            
            setTimeout(() => {
                btn.innerHTML = originalContent;
                btn.disabled = false;
                btn.style.opacity = '1';
                btn.style.background = '';
                this.form.reset();
            }, 3000);
        }, 1500);
    }
}

// ==========================================
// TYPING EFFECT FOR CODE WINDOW
// ==========================================
class CodeTyping {
    constructor() {
        this.codeBody = document.querySelector('.code-body code');
        if (!this.codeBody) return;
        
        this.originalHTML = this.codeBody.innerHTML;
        this.init();
    }

    init() {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    this.startTyping();
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.3 });

        observer.observe(this.codeBody);
    }

    startTyping() {
        const textContent = this.codeBody.textContent;
        this.codeBody.innerHTML = '';
        this.codeBody.style.opacity = '1';
        
        let charIndex = 0;
        const speed = 20;

        const type = () => {
            if (charIndex < textContent.length) {
                // Use original HTML for proper coloring
                const partial = textContent.substring(0, charIndex + 1);
                this.codeBody.textContent = partial;
                charIndex++;
                setTimeout(type, speed);
            } else {
                // Restore original HTML with colors
                this.codeBody.innerHTML = this.originalHTML;
            }
        };

        type();
    }
}

// ==========================================
// CURSOR GLOW EFFECT
// ==========================================
class CursorGlow {
    constructor() {
        this.init();
    }

    init() {
        const glow = document.createElement('div');
        glow.style.cssText = `
            position: fixed;
            width: 400px;
            height: 400px;
            border-radius: 50%;
            background: radial-gradient(circle, rgba(108, 92, 231, 0.08) 0%, transparent 70%);
            pointer-events: none;
            z-index: 0;
            transform: translate(-50%, -50%);
            transition: opacity 0.3s ease;
        `;
        document.body.appendChild(glow);

        let mouseX = 0, mouseY = 0;
        let glowX = 0, glowY = 0;

        window.addEventListener('mousemove', (e) => {
            mouseX = e.clientX;
            mouseY = e.clientY;
        });

        const animate = () => {
            glowX += (mouseX - glowX) * 0.1;
            glowY += (mouseY - glowY) * 0.1;
            glow.style.left = `${glowX}px`;
            glow.style.top = `${glowY}px`;
            requestAnimationFrame(animate);
        };
        animate();
    }
}

// ==========================================
// INITIALIZE
// ==========================================
document.addEventListener('DOMContentLoaded', () => {
    new ParticleBackground();
    new Navigation();
    new ScrollReveal();
    new SkillBars();
    new CounterAnimation();
    new ContactForm();
    new CodeTyping();
    new CursorGlow();
});
