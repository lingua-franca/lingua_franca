function LinguaFrancaHighlightExample(_data) {
	var getPosition = function(element) {
		var xPosition = 0;
		var yPosition = 0;

		while(element) {
			xPosition += (element.offsetLeft - element.scrollLeft + element.clientLeft);
			yPosition += (element.offsetTop - element.scrollTop + element.clientTop);
			element = element.offsetParent;
		}
		return { x: xPosition, y: yPosition };
	}

	var pointer = document.getElementById('lingua-franca-pointer');
	var key = pointer.dataset.i18nExampleKey;

	var title = document.getElementById('lingua-tranca-title');
	if (title) {
		title.innerHTML = document.title.replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&quot;/g, '"');
	}

	var email_from = document.getElementById('lingua-tranca-from');
	if (email_from) {
		email_from.innerHTML = document.querySelector('meta[email-from]').getAttribute('email-from');
	}

	var email_to = document.getElementById('lingua-tranca-to');
	if (email_to) {
		email_to.innerHTML = document.querySelector('meta[email-to]').getAttribute('email-to');
	}

	var example = document.querySelector('[data-i18n-key="' + key + '"]');
	if (example) {
		var rect = example.getBoundingClientRect();
		var parentRect = example.offsetParent.getBoundingClientRect();
		
		var position = getPosition(example);
		var size = {w: example.offsetWidth, h: example.offsetHeight};

		pointer.style.position = 'absolute';
		pointer.style.left = (position.x + (size.w / 2)) + 'px';

		if ((position.y + size.h) < (document.body.offsetHeight / 2)) {
			pointer.style.top = (position.y + size.h) + 'px';
			pointer.className = 'up';
		} else {
			pointer.style.top = position.y + 'px';
			pointer.className = 'down';
		}
		window.scroll(0, position.y - (window.innerHeight / 2));
	}
}

LinguaFrancaHighlightExample();
